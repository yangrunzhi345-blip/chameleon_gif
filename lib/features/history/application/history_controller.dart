import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_history.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import '../../task_queue/application/task_queue_providers.dart';

/// 历史列表控制器(docs/06 M05,docs/09 §9.2 层次一,常驻)。
///
/// 初始异步加载;订阅任务事件流,completed 时自动刷新(§9.5:
/// TaskQueue → completed → HistoryController → 列表刷新)。
/// delete/clear/retry 在 P5-WP3 落地,本阶段仅 list/reload。
class HistoryController extends Notifier<AsyncValue<List<ExportHistory>>> {
  StreamSubscription<ExportTask>? _taskSub;
  final Set<int> _retrying = {};

  @override
  AsyncValue<List<ExportHistory>> build() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen((event) {
      if (event.state == TaskState.completed) {
        unawaited(reload());
      }
    });
    Future.microtask(reload);
    return const AsyncValue.loading();
  }

  /// 重新加载历史列表(时间倒序,仓储保证)。
  Future<void> reload() async {
    try {
      final list = await ref.read(historyRepositoryProvider).list();
      state = AsyncValue.data(list);
    } catch (e, st) {
      // 仓储异常兜底:记日志 + 状态置 error,避免未处理异步错误
      ref.read(appLoggerProvider).e('历史列表加载失败', error: e, stackTrace: st);
      state = AsyncValue.error(e, st);
    }
  }

  /// 清空全部历史(UI 层已二次确认;仅记录级,不删输出文件)。
  Future<void> clear() async {
    await ref.read(historyRepositoryProvider).clear();
    await reload();
  }

  /// 删除单条历史(仅记录级,不删输出文件)。
  Future<void> delete(int id) async {
    await ref.read(historyRepositoryProvider).delete(id);
    await reload();
  }

  /// 重转:按历史 videoPath 重新解析 → 以历史 settings 快照直接入队。
  ///
  /// 返回新 taskId;已在重转中返回 null(重复点击防护);
  /// 解析失败抛 [FilePickException](透传 SourceMissing 等中文文案)。
  /// 注意:禁止跨模块 import ImportVideoUseCase(docs/05 矩阵),
  /// 此处直读 [ParseVideoPort] 端口并做等价包装。
  Future<int?> retry(ExportHistory history) async {
    if (!_retrying.add(history.id)) return null;
    try {
      // 图片模式:直接以历史 imagePaths 重建源入队(不依赖 ffprobe,
      // settings.end 已由提交时装配为总输出时长,校验自然通过)
      final imagePaths = history.imagePaths;
      if (imagePaths != null && imagePaths.isNotEmpty) {
        return ref
            .read(taskQueueControllerProvider.notifier)
            .submitFromImages(
              history.settings,
              ImageGifSource(paths: imagePaths),
            );
      }
      // end null(全片)放行,由 TaskManager.submit 装配视频时长;
      // end == 0("时长未知 → 输出全片"哨兵,见 export_controller.submit
      // 同型守卫)也放行,否则 0 时长历史无法重转
      final end = history.settings.end;
      if (end != null && end > Duration.zero && history.settings.start >= end) {
        throw const FilePickException(
          errorCode: 'GIF_RETRY_INVALID',
          userMessage: '历史参数无效,无法重转',
        );
      }
      final VideoInfo video;
      try {
        video = await ref.read(parseVideoPortProvider).parse(history.videoPath);
      } on FilePickException {
        rethrow;
      } catch (e, st) {
        ref.read(appLoggerProvider).e('重转解析失败', error: e, stackTrace: st);
        throw FilePickException(
          errorCode: 'GIF_PARSE_UNKNOWN',
          userMessage: '视频解析失败,请稍后重试',
          cause: e,
        );
      }
      // 直接入队(不进预览页/不依赖 export 会话);省略 outputDir → 临时目录
      return ref
          .read(taskQueueControllerProvider.notifier)
          .submit(history.settings, video);
    } finally {
      _retrying.remove(history.id);
    }
  }
}

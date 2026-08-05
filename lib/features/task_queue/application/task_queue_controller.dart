import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import 'task_queue_providers.dart';
import 'task_queue_state.dart';

/// 任务队列控制器(docs/09 §9.2 层次一,常驻非 autoDispose)。
///
/// 包装 [TaskManager]:submit/cancel/retry 转发;订阅任务事件流维护
/// [TaskQueueState](进度高频更新不重建 state,由 ExportProgressProvider
/// 独立消费)。UI 层只 watch 状态与进度,不触调度细节。
class TaskQueueController extends Notifier<TaskQueueState> {
  StreamSubscription<ExportTask>? _taskSub;
  bool _restored = false;

  @override
  TaskQueueState build() {
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen((_) => unawaited(_refresh()));
    ref.onDispose(() => _taskSub?.cancel());
    if (!_restored) {
      _restored = true;
      // 启动恢复:扫描仓储 pending 重新排队(§8.3.7);
      // 异步恢复期间可能被销毁(测试容器/应用退出),守卫 ref.mounted;
      // onError 记日志,避免未处理异步错误
      unawaited(
        manager.start().then(
          (_) {
            if (ref.mounted) _refresh();
          },
          onError: (Object e, StackTrace st) {
            ref.read(appLoggerProvider).e('任务恢复启动失败', error: e, stackTrace: st);
          },
        ),
      );
    }
    return const TaskQueueState();
  }

  /// 提交转换任务,返回 taskId([outputDir] 非空时输出到用户目录)。
  Future<int> submit(
    GifSetting setting,
    VideoInfo video, {
    String? outputDir,
  }) async {
    final id = await ref
        .read(taskManagerProvider)
        .submit(setting, video, outputDir: outputDir);
    await _refresh();
    return id;
  }

  /// 提交图片合成任务([source] 为有序图片路径列表)。
  Future<int> submitFromImages(
    GifSetting setting,
    ImageGifSource source, {
    String? outputDir,
  }) async {
    final id = await ref
        .read(taskManagerProvider)
        .submitFromImages(setting, source, outputDir: outputDir);
    await _refresh();
    return id;
  }

  /// 取消任务(queued 直接终态;running 触发令牌与清理)。
  Future<void> cancel(int id) async {
    await ref.read(taskManagerProvider).cancel(id);
    await _refresh();
  }

  /// 取消全部非终态任务(P6-WP2)。
  Future<void> cancelAll() async {
    await ref.read(taskManagerProvider).cancelAll();
    await _refresh();
  }

  /// 重试失败任务(failed → queued 重新排队)。
  Future<void> retry(int id) async {
    await ref.read(taskManagerProvider).retry(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    final tasks = await ref.read(taskManagerProvider).tasks;
    final running = tasks.where((t) => t.state == TaskState.running).toList();
    state = TaskQueueState(tasks: tasks, running: running);
  }
}

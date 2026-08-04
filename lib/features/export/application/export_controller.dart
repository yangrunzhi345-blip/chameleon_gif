import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import '../../task_queue/application/task_queue_providers.dart';
import 'export_state.dart';

/// 导出会话控制器(docs/06 M04,docs/09 §9.2 层次二,autoDispose)。
///
/// 对外:`submit(GifSetting, VideoInfo)`(默认参数装配:end 缺省取
/// video.duration;start≥end 守卫拒绝)、`cancelTask`、`reset`(弹窗关闭回
/// idle)。订阅任务事件流驱动 idle→exporting→done|failed;高频进度不重建
/// 状态(经 exportProgressProvider 独立消费)。
class ExportController extends Notifier<ExportUiState> {
  StreamSubscription<ExportTask>? _taskSub;
  int? _activeTaskId;
  bool _submitting = false;

  @override
  ExportUiState build() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen(_onTaskEvent);
    return const ExportUiState.idle();
  }

  /// 提交导出(默认参数装配:end 缺省取源视频时长;start≥end 拒绝)。
  ///
  /// 重入守卫:await 提交期间按钮仍可点,连点只入队一次。
  Future<void> submit(GifSetting setting, VideoInfo video) async {
    if (_submitting) return;
    _submitting = true;
    try {
      final end = setting.end ?? video.duration;
      if (setting.start >= end) {
        state = const ExportUiState.failed('起点不能晚于或等于终点');
        return;
      }
      final effective = setting.end == null
          ? setting.copyWith(end: video.duration)
          : setting;
      final id = await ref
          .read(taskQueueControllerProvider.notifier)
          .submit(effective, video);
      _activeTaskId = id;
      state = ExportUiState.exporting(id);
    } finally {
      _submitting = false;
    }
  }

  /// 取消当前导出任务。
  Future<void> cancelTask() async {
    final taskId = _activeTaskId;
    if (taskId == null) return;
    await ref.read(taskQueueControllerProvider.notifier).cancel(taskId);
  }

  /// 弹窗/失败提示关闭后回 idle,允许再次导出。
  void reset() {
    _activeTaskId = null;
    state = const ExportUiState.idle();
  }

  /// 在系统文件管理器中打开输出目录(done 态动作,UI 层仅转发)。
  Future<void> openOutputFolder() async {
    final task = state.task;
    final outputPath = task?.outputPath;
    if (outputPath == null) return;
    // 目录提取在功能层(dart:io 纯路径处理,不触文件系统)
    await ref
        .read(platformAdapterProvider)
        .openFolder(File(outputPath).parent.path);
  }

  Future<void> _onTaskEvent(ExportTask task) async {
    final taskId = _activeTaskId;
    if (taskId == null || task.id != taskId) return;
    if (task.state == TaskState.completed) {
      final outputPath = task.outputPath;
      if (outputPath == null) return;
      // 功能层读文件大小(UI 层禁止 IO)
      int size = 0;
      try {
        size = await File(outputPath).length();
      } on FileSystemException {
        // 大小读取失败不阻断完成弹窗
      }
      state = ExportUiState.done(task, size);
    } else if (task.state == TaskState.failed) {
      state = ExportUiState.failed(task.errorDetail ?? '转换失败,请重试');
    } else if (task.state == TaskState.cancelled) {
      state = const ExportUiState.failed('转换已取消');
    }
  }
}

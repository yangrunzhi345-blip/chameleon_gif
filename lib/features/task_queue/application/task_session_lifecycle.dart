import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/platform/gallery_save_result.dart';
import '../../../shared/providers/core_providers.dart';
import 'task_queue_providers.dart';

/// 导出会话生命周期公共样板(export/image_gif 两控制器共用,防跨模块漂移)。
///
/// 抽取逐字相同的部分:任务事件流订阅样板、取消、相册副本延迟删除、
/// 打开输出位置、分享、输出大小读取、提交重入守卫;
/// **状态迁移是子类专属逻辑**(各生命周期枚举与 copyWith 不同),
/// 经抽象成员 [handleTaskEvent]/[sessionTask]/[goIdle] 委托子类。
mixin TaskSessionLifecycle<S> on Notifier<S> {
  StreamSubscription<ExportTask>? _taskSub;
  int? _activeTaskId;
  bool _submitting = false;

  // ---- 子类抽象成员(状态迁移) ----

  /// 任务终态事件 → 会话状态迁移(completed/failed/cancelled 映射到
  /// 各自的生命周期枚举)。
  void handleTaskEvent(ExportTask task);

  /// 从各自 state 取已完成任务(done 态动作与相册副本清理用)。
  ExportTask? get sessionTask;

  /// 弹窗/失败提示关闭后回 idle(表单值保留)。
  void goIdle();

  // ---- 公共实现(逐字抽取,行为不变) ----

  /// build() 首行调用:订阅任务事件流 + onDispose 取消。
  void initTaskSubscription() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen(handleTaskEvent);
  }

  /// 提交重入守卫:成功登记返回 true(调用方进入提交流程),
  /// 已提交中返回 false(忽略连点)。
  bool claimSubmit() {
    if (_submitting) return false;
    _submitting = true;
    return true;
  }

  /// 提交流程结束释放重入守卫(finally 调用)。
  void releaseSubmit() {
    _submitting = false;
  }

  /// 登记当前会话的任务 id(取消/事件过滤的依据)。
  void trackTask(int id) {
    _activeTaskId = id;
  }

  /// 取消当前导出任务。
  Future<void> cancelTask() async {
    final taskId = _activeTaskId;
    if (taskId == null) return;
    await ref.read(taskQueueControllerProvider.notifier).cancel(taskId);
  }

  /// 弹窗/失败提示关闭后回 idle,表单值保留。
  ///
  /// 已保存到相册的私有副本在此延迟删除(弹窗期间路径仍有效,供预览/
  /// 分享);best-effort:删除失败仅日志,系统缓存清理兜底。
  Future<void> resetSession() async {
    final task = sessionTask;
    final outputPath = task?.outputPath;
    if (task?.galleryStatus == GallerySaveStatus.saved && outputPath != null) {
      try {
        final f = File(outputPath);
        if (await f.exists()) await f.delete();
      } on FileSystemException {
        // 忽略:缓存目录系统会兜底清理
      }
    }
    _activeTaskId = null;
    goIdle();
  }

  /// 打开输出位置(done 态动作,UI 层仅转发)。
  ///
  /// 已保存到相册(saved)→ 打开相册定位条目;否则打开文件管理器目录
  /// (桌面);平台路由藏在 PlatformAdapter,UI 无平台分支。
  Future<void> openOutputFolder() async {
    final task = sessionTask;
    final outputPath = task?.outputPath;
    if (task == null || outputPath == null) return;
    if (task.galleryStatus == GallerySaveStatus.saved) {
      await ref.read(platformAdapterProvider).openGallery(uri: task.galleryUri);
      return;
    }
    await ref
        .read(platformAdapterProvider)
        .openFolder(File(outputPath).parent.path);
  }

  /// 系统分享面板发送输出文件(相册保存失败/低版本系统的兜底)。
  Future<void> shareGif() async {
    final outputPath = sessionTask?.outputPath;
    if (outputPath == null) return;
    await ref.read(platformAdapterProvider).shareFile(outputPath);
  }

  /// 读取输出文件大小(失败返回 0,不阻断完成弹窗)。
  Future<int> readOutputSizeBytes(String path) async {
    try {
      return await File(path).length();
    } on FileSystemException {
      return 0;
    }
  }

  /// 完成/失败/取消事件过滤:仅本会话任务。
  bool isSessionTask(ExportTask task) {
    final taskId = _activeTaskId;
    return taskId != null && task.id == taskId;
  }

  /// completed 事件的目标状态(由子类把 task 映射进各自 done 态)。
  ExportTask? completedTask(ExportTask task) =>
      task.state == TaskState.completed ? task : null;
}

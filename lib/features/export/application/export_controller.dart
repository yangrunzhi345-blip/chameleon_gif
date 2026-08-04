import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_math.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import '../../task_queue/application/task_queue_providers.dart';
import '../../timeline/application/timeline_providers.dart';
import 'export_providers.dart';
import 'export_state.dart';

/// 导出会话控制器(docs/06 M04,docs/09 §9.2 层次二,autoDispose)。
///
/// 表单 + 生命周期一体:initForm(应用默认参数)/update*(钳制)/syncRange
/// (时间轴提交回调)/saveAsDefault/loadDefault/submit(表单装配,start==end
/// 拒绝,start>end 自动交换)/cancelTask/reset(保留表单值)。
/// 订阅任务事件流驱动 idle→exporting→done|failed;高频进度不重建状态。
class ExportController extends Notifier<ExportFormState> {
  StreamSubscription<ExportTask>? _taskSub;
  int? _activeTaskId;
  bool _submitting = false;
  Duration? _videoDuration;

  @override
  ExportFormState build() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen(_onTaskEvent);
    return const ExportFormState.idle();
  }

  /// 会话初始化:缓存视频时长 + 应用默认参数(无则内置默认)。
  void initForm({required VideoInfo video}) {
    _videoDuration = video.duration;
    final saved = ref.read(settingsRepositoryProvider).defaultGifSetting;
    final base = saved ?? const GifSetting();
    state = state.copyWith(
      fps: base.fps.clamp(1, 60),
      width: base.width.clamp(0, 4096),
      loop: base.loop.clamp(0, 100),
      start: base.start,
      end: base.end,
      formError: null,
    );
  }

  /// 重新应用持久化默认参数(载入默认按钮;无默认时不动表单)。
  void loadDefault() {
    final saved = ref.read(settingsRepositoryProvider).defaultGifSetting;
    if (saved == null) return;
    state = state.copyWith(
      fps: saved.fps.clamp(1, 60),
      width: saved.width.clamp(0, 4096),
      loop: saved.loop.clamp(0, 100),
      start: saved.start,
      end: saved.end,
      formError: null,
    );
  }

  /// 保存当前表单为默认参数(SharedPreferences 持久化)。
  Future<void> saveAsDefault() {
    return ref
        .read(settingsRepositoryProvider)
        .setDefaultGifSetting(assembleSetting());
  }

  // ---- 表单更新(导出中锁定) ----

  /// 帧率(钳制 1–60)。
  void updateFps(double fps) {
    if (state.locked) return;
    state = state.copyWith(fps: fps.clamp(1, 60), formError: null);
  }

  /// 宽度(钳制 0–4096,0 = 原图等比)。
  void updateWidth(int width) {
    if (state.locked) return;
    state = state.copyWith(width: width.clamp(0, 4096), formError: null);
  }

  /// 循环次数(钳制 0–100,0 = 无限)。
  void updateLoop(int loop) {
    if (state.locked) return;
    state = state.copyWith(loop: loop.clamp(0, 100), formError: null);
  }

  /// 起点(钳制 + 与终点自动交换 + 同步时间轴)。
  void updateStart(Duration start) {
    if (state.locked) return;
    final (s, e) = _normalized(start, state.end);
    state = state.copyWith(start: s, end: e, formError: null);
    ref.read(timelineControllerProvider.notifier).setStart(s);
  }

  /// 终点(null = 到视频结尾;钳制 + 交换 + 同步时间轴)。
  void updateEnd(Duration? end) {
    if (state.locked) return;
    if (end == null) {
      state = state.copyWith(end: null, formError: null);
      ref
          .read(timelineControllerProvider.notifier)
          .setEnd(_videoDuration ?? Duration.zero);
      return;
    }
    final (s, e) = _normalized(state.start, end);
    state = state.copyWith(start: s, end: e, formError: null);
    ref.read(timelineControllerProvider.notifier).setEnd(e);
  }

  /// 时间轴提交回调:表单镜像选区(WP3 接线;钳制幂等)。
  void syncRange({required Duration start, required Duration end}) {
    if (state.locked) return;
    state = state.copyWith(start: start, end: end, formError: null);
  }

  /// 表单 → GifSetting(end 保留 null,由 TaskManager 装配视频时长)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    width: state.width,
    loop: state.loop,
    start: state.start,
    end: state.end,
  );

  /// 设置导出目录(空串 → null = 系统临时目录)。
  void updateOutputDir(String? dir) {
    if (state.locked) return;
    state = state.copyWith(
      outputDir: (dir == null || dir.isEmpty) ? null : dir,
      formError: null,
    );
  }

  /// 打开系统目录选择器;成功后回填表单并持久化为默认导出目录。
  ///
  /// 取消(null)静默;选择失败 → formError 中文提示。
  Future<void> pickOutputDir() async {
    if (state.locked) return;
    final initial =
        state.outputDir ??
        ref.read(settingsRepositoryProvider).defaultExportDir;
    try {
      final dir = await ref
          .read(directoryPickPortProvider)
          .pickDirectory(initialDirectory: initial.isEmpty ? null : initial);
      if (dir == null) return; // 用户取消
      updateOutputDir(dir);
      await ref.read(settingsRepositoryProvider).setDefaultExportDir(dir);
    } on FilePickException catch (e) {
      if (state.locked) return;
      state = state.copyWith(formError: e.userMessage);
    }
  }

  /// 设置表单级错误(时间格式非法等;非空时禁用导出)。
  void updateFormError(String message) {
    if (state.locked) return;
    state = state.copyWith(formError: message);
  }

  /// 清除表单级错误(输入修正后)。
  void clearFormError() {
    state = state.copyWith(formError: null);
  }

  // ---- 生命周期 ----

  /// 提交导出(默认参数装配;start>end 自动交换;start==end 拒绝)。
  ///
  /// [setting] 非空时绕过表单(测试/P5 重转直传);重入守卫防连点。
  Future<void> submit({GifSetting? setting, required VideoInfo video}) async {
    if (_submitting) return;
    _submitting = true;
    try {
      final effective = setting ?? assembleSetting();
      final end = effective.end ?? video.duration;
      if (effective.start >= end) {
        state = state.copyWith(
          lifecycle: ExportLifecycle.failed,
          errorMessage: '起点不能晚于或等于终点',
        );
        return;
      }
      final id = await ref
          .read(taskQueueControllerProvider.notifier)
          .submit(effective, video, outputDir: state.outputDir);
      _activeTaskId = id;
      state = state.copyWith(
        lifecycle: ExportLifecycle.exporting,
        taskId: id,
        formError: null,
      );
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

  /// 弹窗/失败提示关闭后回 idle,表单值保留。
  void reset() {
    _activeTaskId = null;
    state = state.copyWith(
      lifecycle: ExportLifecycle.idle,
      taskId: null,
      task: null,
      errorMessage: null,
    );
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

  (Duration, Duration) _normalized(Duration start, Duration? end) {
    final max = _videoDuration ?? Duration.zero;
    final s = start < Duration.zero
        ? Duration.zero
        : (start > max ? max : start);
    final e = end == null ? max : (end > max ? max : end);
    return normalizeRange(s, e);
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
      state = state.copyWith(
        lifecycle: ExportLifecycle.done,
        task: task,
        outputSizeBytes: size,
      );
    } else if (task.state == TaskState.failed) {
      state = state.copyWith(
        lifecycle: ExportLifecycle.failed,
        errorMessage: task.errorDetail ?? '转换失败,请重试',
      );
    } else if (task.state == TaskState.cancelled) {
      state = state.copyWith(
        lifecycle: ExportLifecycle.failed,
        errorMessage: '转换已取消',
      );
    }
  }
}

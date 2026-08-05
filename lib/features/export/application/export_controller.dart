import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_math.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import '../../task_queue/application/task_queue_providers.dart';
import '../../task_queue/application/task_session_lifecycle.dart';
import '../../timeline/application/timeline_providers.dart';
import 'export_state.dart';
// 别名:顶层函数与本控制器方法同名,须经别名调用
import 'output_dir_picker.dart' as output_dir_picker;

/// 导出会话控制器(docs/06 M04,docs/09 §9.2 层次二,autoDispose)。
///
/// 表单 + 生命周期一体:initForm(应用默认参数)/update*(钳制)/syncRange
/// (时间轴提交回调)/saveAsDefault/loadDefault/submit(表单装配,start==end
/// 拒绝,start>end 自动交换)/cancelTask/reset(保留表单值)。
/// 订阅任务事件流驱动 idle→exporting→done|failed;高频进度不重建状态。
/// 生命周期公共样板(订阅/取消/相册清理/打开/分享)经 [TaskSessionLifecycle]
/// 抽取,本类只保留状态迁移与表单逻辑。
class ExportController extends Notifier<ExportFormState>
    with TaskSessionLifecycle<ExportFormState> {
  Duration? _videoDuration;

  @override
  ExportFormState build() {
    initTaskSubscription();
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
      height: base.height.clamp(0, 4096),
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
      height: saved.height.clamp(0, 4096),
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

  /// 高度(钳制 0–4096,0 = 原图等比)。
  void updateHeight(int height) {
    if (state.locked) return;
    state = state.copyWith(height: height.clamp(0, 4096), formError: null);
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
    height: state.height,
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
  /// (公共动作见 output_dir_picker.dart)
  Future<void> pickOutputDir() {
    return output_dir_picker.pickOutputDir(
      ref: ref,
      currentOutputDir: state.outputDir,
      locked: state.locked,
      onPicked: updateOutputDir,
      onError: (message) => state = state.copyWith(formError: message),
    );
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
    if (!claimSubmit()) return;
    try {
      final effective = setting ?? assembleSetting();
      final end = effective.end ?? video.duration;
      // end == 0 是"时长未知 → 输出全片"哨兵(command_builder._trimArgs
      // 省略 -to),此时 start>=end 恒真;仅 end>0 才做区间校验,
      // 否则时长元数据为 0 的视频被恒定拒绝、永远无法导出
      if (end > Duration.zero && effective.start >= end) {
        state = state.copyWith(
          lifecycle: ExportLifecycle.failed,
          errorMessage: '起点不能晚于或等于终点',
        );
        return;
      }
      final id = await ref
          .read(taskQueueControllerProvider.notifier)
          .submit(effective, video, outputDir: state.outputDir);
      trackTask(id);
      state = state.copyWith(
        lifecycle: ExportLifecycle.exporting,
        taskId: id,
        formError: null,
      );
    } finally {
      releaseSubmit();
    }
  }

  /// 弹窗/失败提示关闭后回 idle,表单值保留(公共逻辑见
  /// [TaskSessionLifecycle.resetSession])。
  Future<void> reset() => resetSession();

  (Duration, Duration) _normalized(Duration start, Duration? end) {
    final max = _videoDuration ?? Duration.zero;
    final s = start < Duration.zero
        ? Duration.zero
        : (start > max ? max : start);
    final e = end == null ? max : (end > max ? max : end);
    return normalizeRange(s, e);
  }

  // ---- TaskSessionLifecycle 状态迁移 ----

  @override
  ExportTask? get sessionTask => state.task;

  @override
  void goIdle() {
    state = state.copyWith(
      lifecycle: ExportLifecycle.idle,
      taskId: null,
      task: null,
      errorMessage: null,
    );
  }

  @override
  void handleTaskEvent(ExportTask task) {
    if (!isSessionTask(task)) return;
    if (task.state == TaskState.completed) {
      final outputPath = task.outputPath;
      if (outputPath == null) return;
      // 功能层读文件大小(UI 层禁止 IO;失败不阻断完成弹窗)
      unawaited(
        readOutputSizeBytes(outputPath).then((size) {
          state = state.copyWith(
            lifecycle: ExportLifecycle.done,
            task: task,
            outputSizeBytes: size,
          );
        }),
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

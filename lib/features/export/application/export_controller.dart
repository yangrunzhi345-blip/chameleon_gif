import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
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
import 'scale_multiplier.dart';
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

  /// 源视频尺寸缓存(>0 才填充;倍数联动与提交展开的依据)。
  ({int width, int height})? _sourceSize;

  @override
  ExportFormState build() {
    initTaskSubscription();
    return const ExportFormState.idle();
  }

  /// 会话初始化:缓存视频尺寸/时长 + 应用默认参数(无则内置默认)。
  void initForm({required VideoInfo video}) {
    _videoDuration = video.duration;
    _sourceSize = (video.width > 0 && video.height > 0)
        ? (width: video.width, height: video.height)
        : null;
    final saved = ref.read(settingsRepositoryProvider).defaultGifSetting;
    final base = saved ?? const GifSetting();
    final w = base.width.clamp(0, 4096);
    final h = base.height.clamp(0, 4096);
    state = state.copyWith(
      fps: base.fps.clamp(1, 60),
      width: w,
      height: h,
      loop: base.loop.clamp(0, 100),
      start: base.start,
      end: base.end,
      playbackSpeed: base.playbackSpeed.clamp(0.25, 4),
      formError: null,
    );
    _applyLoadedMultiplier(w, h, base.scaleMultiplier);
  }

  /// 重新应用持久化默认参数(载入默认按钮;无默认时不动表单)。
  void loadDefault() {
    final saved = ref.read(settingsRepositoryProvider).defaultGifSetting;
    if (saved == null) return;
    final w = saved.width.clamp(0, 4096);
    final h = saved.height.clamp(0, 4096);
    state = state.copyWith(
      fps: saved.fps.clamp(1, 60),
      width: w,
      height: h,
      loop: saved.loop.clamp(0, 100),
      start: saved.start,
      end: saved.end,
      playbackSpeed: saved.playbackSpeed.clamp(0.25, 4),
      formError: null,
    );
    _applyLoadedMultiplier(w, h, saved.scaleMultiplier);
  }

  /// 载入默认参数后的倍数归一:
  /// - 宽高全 0 且倍数非 1 且源尺寸已知 → 落成具体宽高(兑现持久化
  ///   倍数意图,如设置页存的"2 倍")
  /// - 否则按 [matchScaleMultiplier] 回显(命中选项 → 该倍数;
  ///   (0,0) → 1.0;手动宽高不匹配 → null = 自定义)
  void _applyLoadedMultiplier(int w, int h, double m) {
    final src = _sourceSize;
    if (src != null && w == 0 && h == 0 && (m - 1.0).abs() > 1e-9) {
      state = state.copyWith(
        width: scaledDimension(src.width, m),
        height: scaledDimension(src.height, m),
        scaleMultiplier: m,
      );
      return;
    }
    state = state.copyWith(
      scaleMultiplier: _echoMultiplier(width: w, height: h),
    );
  }

  /// 当前宽高对应的倍数回显(见 _applyLoadedMultiplier 注释)。
  double? _echoMultiplier({required int width, required int height}) {
    final src = _sourceSize;
    if (width == 0 && height == 0) return 1.0;
    if (src == null) return null;
    return matchScaleMultiplier(
      sourceWidth: src.width,
      sourceHeight: src.height,
      width: width,
      height: height,
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

  /// 宽度(钳制 0–4096,0 = 原图等比;手动指定后倍数回显"自定义")。
  void updateWidth(int width) {
    if (state.locked) return;
    final w = width.clamp(0, 4096);
    state = state.copyWith(
      width: w,
      scaleMultiplier: _echoMultiplier(width: w, height: state.height),
      formError: null,
    );
  }

  /// 高度(钳制 0–4096,0 = 原图等比;手动指定后倍数回显"自定义")。
  void updateHeight(int height) {
    if (state.locked) return;
    final h = height.clamp(0, 4096);
    state = state.copyWith(
      height: h,
      scaleMultiplier: _echoMultiplier(width: state.width, height: h),
      formError: null,
    );
  }

  /// 等比缩放倍数(0.5–3;源尺寸已知时联动落成具体宽高,保持比例)。
  void updateScaleMultiplier(double multiplier) {
    if (state.locked) return;
    final src = _sourceSize;
    if (src != null) {
      state = state.copyWith(
        width: scaledDimension(src.width, multiplier),
        height: scaledDimension(src.height, multiplier),
        scaleMultiplier: multiplier,
        formError: null,
      );
      return;
    }
    // 源尺寸未知(解析异常):仅存偏好,提交时无源可展开(原样输出)
    state = state.copyWith(scaleMultiplier: multiplier, formError: null);
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

  /// 播放速度(钳制 0.25–4:<1 慢放,>1 加速;命令侧 setpts)。
  void updatePlaybackSpeed(double speed) {
    if (state.locked) return;
    state = state.copyWith(
      playbackSpeed: speed.clamp(0.25, 4),
      formError: null,
    );
  }

  // ---- 文本输入解析+校验(UI 文本 → 状态,短路语义) ----
  // 与 image_gif_controller 的 try* 系列同构:解析/范围校验/错误文案下沉
  // 控制器(去除 UI 层重复实现);任一失败设 formError 返回 false,调用方
  // 逐字段短路调用(后项成功不清前项错误)。

  /// 循环次数文本:非数字 → formError 返回 false;成功应用清错返回 true。
  bool tryUpdateLoopText(String text) {
    if (state.locked) return false;
    final v = int.tryParse(text.trim());
    if (v == null) {
      state = state.copyWith(formError: '循环次数须为数字');
      return false;
    }
    updateLoop(v);
    return true;
  }

  /// 开始时间文本:格式非法 → formError 返回 false;成功(含钳制/交换/
  /// 时间轴同步)返回 true。
  bool tryUpdateStartText(String text) {
    if (state.locked) return false;
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      state = state.copyWith(formError: '开始时间格式非法(示例 00:03.200)');
      return false;
    }
    updateStart(parsed);
    return true;
  }

  /// 结束时间文本:留空 → null(到视频结尾);格式非法 → formError 返回 false。
  bool tryUpdateEndText(String text) {
    if (state.locked) return false;
    if (text.trim().isEmpty) {
      updateEnd(null);
      return true;
    }
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      state = state.copyWith(formError: '结束时间格式非法(示例 00:09.500)');
      return false;
    }
    updateEnd(parsed);
    return true;
  }

  /// 自定义宽度文本(1–4096;成功时联动倍数回显,同短路语义)。
  bool tryUpdateCustomWidth(String text) {
    if (state.locked) return false;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      state = state.copyWith(formError: '宽度须为 1–4096 的数字');
      return false;
    }
    updateWidth(v);
    return true;
  }

  /// 自定义高度文本(1–4096;成功时联动倍数回显,同短路语义)。
  bool tryUpdateCustomHeight(String text) {
    if (state.locked) return false;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      state = state.copyWith(formError: '高度须为 1–4096 的数字');
      return false;
    }
    updateHeight(v);
    return true;
  }

  /// 自定义缩放倍数文本(0.1–4;成功落成宽高联动,同短路语义)。
  bool tryUpdateCustomScaleMultiplier(String text) {
    if (state.locked) return false;
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0 || v > 4) {
      state = state.copyWith(formError: '缩放倍数须为 0.1–4 的数字');
      return false;
    }
    updateScaleMultiplier(v);
    return true;
  }

  /// 表单 → GifSetting(end 保留 null,由 TaskManager 装配视频时长;
  /// 倍数 null = 自定义,持久化时归一为 1.0)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    width: state.width,
    height: state.height,
    loop: state.loop,
    start: state.start,
    end: state.end,
    scaleMultiplier: state.scaleMultiplier ?? 1.0,
    playbackSpeed: state.playbackSpeed,
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
      // 防御性展开:直传 setting(测试/重转)未展开倍数时补一次
      // (源尺寸未知或宽高已指定时工具内守卫自动跳过)
      final expanded = _sourceSize == null
          ? effective
          : expandScaleMultiplier(
              effective,
              sourceWidth: _sourceSize!.width,
              sourceHeight: _sourceSize!.height,
            );
      final end = expanded.end ?? video.duration;
      // end == 0 是"时长未知 → 输出全片"哨兵(command_builder._trimArgs
      // 省略 -to),此时 start>=end 恒真;仅 end>0 才做区间校验,
      // 否则时长元数据为 0 的视频被恒定拒绝、永远无法导出
      if (end > Duration.zero && expanded.start >= end) {
        state = state.copyWith(
          lifecycle: ExportLifecycle.failed,
          errorMessage: '起点不能晚于或等于终点',
        );
        return;
      }
      final int id;
      try {
        id = await ref
            .read(taskQueueControllerProvider.notifier)
            .submit(expanded, video, outputDir: state.outputDir);
      } catch (e, st) {
        // 入队失败(Isar 写库等)不直抛给 UI:转表单错误提示并记录
        ref.read(appLoggerProvider).e('导出任务入队失败', error: e, stackTrace: st);
        if (ref.mounted) {
          state = state.copyWith(formError: '任务入队失败,请重试');
        }
        return;
      }
      if (!ref.mounted) return; // autoDispose 会话销毁(页面已离开)
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
      // 已 done 去重:重复 completed 事件(或 done 态期间的事件)不得
      // 再次写 done —— 每次写入都会让页面 listener 重弹完成弹窗(BUG1)
      if (state.lifecycle == ExportLifecycle.done) return;
      final outputPath = task.outputPath;
      if (outputPath == null) return;
      // 功能层读文件大小(UI 层禁止 IO;失败不阻断完成弹窗)
      unawaited(
        readOutputSizeBytes(outputPath).then((size) {
          // 续体落地时复查:会话销毁或已 done(reset 后未决续体)不复活
          if (!ref.mounted) return; // autoDispose 会话销毁(页面已离开)
          if (state.lifecycle == ExportLifecycle.done) return;
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

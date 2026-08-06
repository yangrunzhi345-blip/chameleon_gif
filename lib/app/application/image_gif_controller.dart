import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/export_task.dart';
import '../../domain/entities/image_gif_source.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../domain/value_objects/per_image_control.dart';
import '../../domain/value_objects/task_state.dart';
import '../../features/export/application/output_dir_picker.dart'
    as output_dir_picker;
import '../../features/export/application/scale_multiplier.dart';
import '../../features/import/application/import_providers.dart';
import '../../features/task_queue/application/task_queue_providers.dart';
import '../../features/task_queue/application/task_session_lifecycle.dart';
import '../../shared/providers/core_providers.dart';
import 'image_gif_state.dart';

/// 图片制作 GIF 会话控制器 provider(会话级,autoDispose)。
final imageGifControllerProvider =
    NotifierProvider.autoDispose<ImageGifController, ImageGifFormState>(
      ImageGifController.new,
    );

/// 图片制作 GIF 会话控制器(app 层跨模块组合,autoDispose,
/// 生命周期与 [ExportController] 同构)。
///
/// 表单 + 生命周期一体:init(应用默认参数)/update*(钳制与下限校验)/
/// saveAsDefault/submit(装配 GifSetting + ImageGifSource → 任务队列)/
/// cancelTask/reset(保留表单值)/openOutputFolder/shareGif。
/// 订阅任务事件流驱动 idle→exporting→done|failed;高频进度不重建状态。
/// 生命周期公共样板经 [TaskSessionLifecycle] 抽取(与 export 同源)。
class ImageGifController extends Notifier<ImageGifFormState>
    with TaskSessionLifecycle<ImageGifFormState> {
  /// 首图尺寸缓存(探测成功后填充;倍数联动与提交展开的依据)。
  ({int width, int height})? _sourceSize;

  /// 当前输出画布尺寸(精细控制页预览框比例用;null = 未知)。
  ///
  /// 规则与命令构造 `_canvasSize` 一致:表单宽高双边指定 → 指定尺寸;
  /// 单边 → 另一侧按首图比例推算;均 0 → 首图尺寸;首图未知 → null。
  ({int width, int height})? get canvasSize {
    final w = state.width;
    final h = state.height;
    final src = _sourceSize;
    if (w > 0 && h > 0) return (width: w, height: h);
    if (src == null || src.width <= 0 || src.height <= 0) return null;
    if (w > 0) {
      return (
        width: w,
        height: math.max(1, (w * src.height / src.width).round()),
      );
    }
    if (h > 0) {
      return (
        width: math.max(1, (h * src.width / src.height).round()),
        height: h,
      );
    }
    return src;
  }

  /// 已探测的首图路径(去重:同一首图不重复探测)。
  String? _probedPath;

  @override
  ImageGifFormState build() {
    initTaskSubscription();
    return const ImageGifFormState.idle();
  }

  /// 会话初始化:应用持久化默认参数(fps/width/height/loop/usePalette 继承;
  /// frameDurationMs 无默认时 1000ms;outputDir 取默认导出目录;
  /// 倍数载入:宽高全 0 时继承偏好,否则 null = 自定义)。
  void init() {
    final repo = ref.read(settingsRepositoryProvider);
    final saved = repo.defaultGifSetting;
    final base = saved ?? const GifSetting();
    final outputDir = repo.defaultExportDir;
    final w = base.width.clamp(0, 4096);
    final h = base.height.clamp(0, 4096);
    state = state.copyWith(
      fps: base.fps.clamp(1, 60),
      frameDurationMs: (base.frameDurationMs ?? 1000)
          .clamp((1000 / base.fps.clamp(1, 60)).ceil(), 60000)
          .toInt(),
      width: w,
      height: h,
      loop: base.loop.clamp(0, 100),
      usePalette: base.usePalette,
      outputDir: outputDir.isEmpty ? null : outputDir,
      scaleMultiplier: (w == 0 && h == 0) ? base.scaleMultiplier : null,
      playbackSpeed: base.playbackSpeed.clamp(0.25, 4),
      formError: null,
    );
    // 首图尺寸在 UI 侧 init 后经 updatePaths 探测,探测成功后若
    // 宽高全 0 且倍数非 1 → 联动回填具体尺寸(兑现持久化倍数意图)
  }

  /// 首图变化时探测尺寸(首路径去重;成功缓存,供倍数联动与提交展开;
  /// 失败静默置空,submit 原有探测与 formError 兜底)。
  Future<void> updatePaths(List<String> paths) async {
    if (state.locked) return;
    if (paths.isEmpty || paths.first == _probedPath) return;
    _probedPath = paths.first;
    final size = await _probeFirstImageSize(paths);
    if (size.width == 0 || size.height == 0) {
      _sourceSize = null;
      return;
    }
    _sourceSize = (width: size.width, height: size.height);
    final m = state.scaleMultiplier;
    if (state.width == 0 &&
        state.height == 0 &&
        m != null &&
        (m - 1.0).abs() > 1e-9) {
      // 宽高全 0 且倍数非 1 → 按首图尺寸 × 倍数联动回填
      state = state.copyWith(
        width: scaledDimension(size.width, m),
        height: scaledDimension(size.height, m),
      );
      return;
    }
    // 其余情形按回显规则刷新倍数(源已知后可匹配)
    state = state.copyWith(
      scaleMultiplier: _echoMultiplier(
        width: state.width,
        height: state.height,
      ),
    );
  }

  /// 当前宽高对应的倍数回显:
  /// - (0,0) 原图等比:源已知 → 1.0(不缩放);源未知 → 保持偏好
  /// - 手动宽高:源已知时匹配选项(命中 → 该倍数,否则 null = 自定义);
  ///   源未知 → null
  double? _echoMultiplier({required int width, required int height}) {
    final src = _sourceSize;
    if (width == 0 && height == 0) {
      return src != null ? 1.0 : (state.scaleMultiplier ?? 1.0);
    }
    if (src == null) return null;
    return matchScaleMultiplier(
      sourceWidth: src.width,
      sourceHeight: src.height,
      width: width,
      height: height,
    );
  }

  // ---- 表单更新(导出中锁定) ----

  /// 帧率(钳制 1–60;帧率变化联动每图时长下限)。
  void updateFps(double fps) {
    if (state.locked) return;
    final clamped = fps.clamp(1, 60).toDouble();
    // 新帧率下限高于当前每图时长 → 自动抬升,避免 0 帧图
    final min = (1000 / clamped).ceil();
    state = state.copyWith(
      fps: clamped,
      frameDurationMs: state.frameDurationMs < min
          ? min
          : state.frameDurationMs,
      formError: null,
    );
  }

  /// 每图停留时长(毫秒;钳制 [ceil(1000/fps), 60000],非法 → formError)。
  void updateFrameDurationMs(int ms) {
    if (state.locked) return;
    final min = state.minFrameDurationMs;
    if (ms < min || ms > 60000) {
      state = state.copyWith(formError: '每张图片停留时长需在 $min–60000 毫秒');
      return;
    }
    state = state.copyWith(frameDurationMs: ms, formError: null);
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

  /// 等比缩放倍数(0.5–3;首图尺寸已知时联动落成具体宽高,保持比例;
  /// 未知时重置宽高 0 仅存偏好,待探测成功后联动回填)。
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
    state = state.copyWith(
      width: 0,
      height: 0,
      scaleMultiplier: multiplier,
      formError: null,
    );
  }

  /// 循环次数(钳制 0–100,0 = 无限)。
  void updateLoop(int loop) {
    if (state.locked) return;
    state = state.copyWith(loop: loop.clamp(0, 100), formError: null);
  }

  /// 播放速度(钳制 0.25–4:<1 慢放,>1 加速;命令侧 setpts)。
  void updatePlaybackSpeed(double speed) {
    if (state.locked) return;
    state = state.copyWith(
      playbackSpeed: speed.clamp(0.25, 4),
      formError: null,
    );
  }

  /// 质量开关(高质两遍 / 标准单遍)。
  void updateUsePalette(bool usePalette) {
    if (state.locked) return;
    state = state.copyWith(usePalette: usePalette, formError: null);
  }

  /// 设置导出目录(空串 → null = 系统临时目录)。
  void updateOutputDir(String? dir) {
    if (state.locked) return;
    state = state.copyWith(
      outputDir: (dir == null || dir.isEmpty) ? null : dir,
      formError: null,
    );
  }

  /// 打开系统目录选择器;成功后回填表单并持久化为默认导出目录。
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

  /// 设置表单级错误(UI 层输入异常等;非空时禁用导出)。
  void updateFormError(String message) {
    if (state.locked) return;
    state = state.copyWith(formError: message);
  }

  /// 清除表单级错误(输入修正后)。
  void clearFormError() {
    state = state.copyWith(formError: null);
  }

  /// 保存当前表单为默认参数(SharedPreferences 持久化)。
  Future<void> saveAsDefault() {
    return ref
        .read(settingsRepositoryProvider)
        .setDefaultGifSetting(assembleSetting());
  }

  /// 表单 → GifSetting(start 恒 zero、end 留 null,由 TaskManager
  /// 装配总输出时长;倍数 null = 自定义,持久化时归一为 1.0)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    frameDurationMs: state.frameDurationMs,
    width: state.width,
    height: state.height,
    loop: state.loop,
    usePalette: state.usePalette,
    scaleMultiplier: state.scaleMultiplier ?? 1.0,
    playbackSpeed: state.playbackSpeed,
  );

  // ---- 生命周期 ----

  /// 提交图片合成任务(多图 → GIF,入任务队列)。
  ///
  /// [paths] 有序图片路径(≥1);首图尺寸经 [imageProbePortProvider] 在
  /// application 内探测(命令构造据此决定是否统一分辨率,UI 不再持有
  /// 解码逻辑,可独立单测)。探测失败 → formError 明确拦截(此前为
  /// 静默退化,后续 concat 神秘报错);空列表拒绝;重入守卫防连点。
  ///
  /// [perImageControls] 为每图精细化控制(与 [paths] 索引对齐,元素可空
  /// = 该图未操作);归一化后**全部默认 → null**(不持久化、命令走默认
  /// 链),否则构造 [ImageGifSource.perImageControls] 随任务/历史持久化。
  Future<void> submit(
    List<String> paths, {
    List<PerImageControl?>? perImageControls,
  }) async {
    if (!claimSubmit()) return;
    if (paths.isEmpty) {
      releaseSubmit();
      state = state.copyWith(formError: '请先选择图片');
      return;
    }
    try {
      final setting = assembleSetting();
      final size = await _probeFirstImageSize(paths);
      if (size.width == 0 || size.height == 0) {
        state = state.copyWith(formError: '无法读取首图尺寸,请更换图片');
        return;
      }
      // 提交时展开倍数(宽高全 0 且倍数非 1 → 首图尺寸 × 倍数落成
      // 具体宽高;任务参数自包含,命令构造零改动)
      final expanded = expandScaleMultiplier(
        setting,
        sourceWidth: size.width,
        sourceHeight: size.height,
      );
      final id = await ref
          .read(taskQueueControllerProvider.notifier)
          .submitFromImages(
            expanded,
            ImageGifSource(
              paths: paths,
              width: size.width,
              height: size.height,
              perImageControls: _normalizePerImageControls(
                paths.length,
                perImageControls,
              ),
            ),
            outputDir: state.outputDir,
          );
      if (!ref.mounted) return; // autoDispose 会话已销毁(页面离开)
      trackTask(id);
      state = state.copyWith(
        lifecycle: ImageGifLifecycle.exporting,
        taskId: id,
        formError: null,
      );
    } finally {
      releaseSubmit();
    }
  }

  /// 探测首图尺寸(失败静默返回 0,由 submit 侧拦截)。
  Future<({int width, int height})> _probeFirstImageSize(
    List<String> paths,
  ) async {
    try {
      return await ref.read(imageProbePortProvider).probe(paths.first);
    } catch (e) {
      ref.read(appLoggerProvider).w('首图尺寸探测失败: ${paths.first}', error: e);
      return (width: 0, height: 0);
    }
  }

  /// 每图控制归一化:null 元素 → 默认值对象;长度与图片数对齐(截断/
  /// 补齐);全部默认 → null(不产生控制、不持久化)。
  List<PerImageControl>? _normalizePerImageControls(
    int count,
    List<PerImageControl?>? raw,
  ) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = <PerImageControl>[
      for (var i = 0; i < count; i++)
        (i < raw.length ? raw[i] : null) ?? const PerImageControl(),
    ];
    if (normalized.every((c) => c.isDefault)) return null;
    return normalized;
  }

  /// 弹窗/失败提示关闭后回 idle,表单值保留(公共逻辑见
  /// [TaskSessionLifecycle.resetSession])。
  Future<void> reset() => resetSession();

  // ---- TaskSessionLifecycle 状态迁移 ----

  @override
  ExportTask? get sessionTask => state.task;

  @override
  void goIdle() {
    state = state.copyWith(
      lifecycle: ImageGifLifecycle.idle,
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
            lifecycle: ImageGifLifecycle.done,
            task: task,
            outputSizeBytes: size,
          );
        }),
      );
    } else if (task.state == TaskState.failed) {
      state = state.copyWith(
        lifecycle: ImageGifLifecycle.failed,
        errorMessage: task.errorDetail ?? '转换失败,请重试',
      );
    } else if (task.state == TaskState.cancelled) {
      state = state.copyWith(
        lifecycle: ImageGifLifecycle.failed,
        errorMessage: '转换已取消',
      );
    }
  }
}

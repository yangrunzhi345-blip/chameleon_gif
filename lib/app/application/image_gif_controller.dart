import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/export_task.dart';
import '../../domain/entities/image_gif_source.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../domain/value_objects/task_state.dart';
import '../../features/export/application/output_dir_picker.dart'
    as output_dir_picker;
import '../../features/task_queue/application/task_queue_providers.dart';
import '../../shared/platform/gallery_save_result.dart';
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
class ImageGifController extends Notifier<ImageGifFormState> {
  StreamSubscription<ExportTask>? _taskSub;
  int? _activeTaskId;
  bool _submitting = false;

  @override
  ImageGifFormState build() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen(_onTaskEvent);
    return const ImageGifFormState.idle();
  }

  /// 会话初始化:应用持久化默认参数(fps/width/height/loop/usePalette 继承;
  /// frameDurationMs 无默认时 1000ms;outputDir 取默认导出目录)。
  void init() {
    final repo = ref.read(settingsRepositoryProvider);
    final saved = repo.defaultGifSetting;
    final base = saved ?? const GifSetting();
    final outputDir = repo.defaultExportDir;
    state = state.copyWith(
      fps: base.fps.clamp(1, 60),
      frameDurationMs: (base.frameDurationMs ?? 1000)
          .clamp((1000 / base.fps.clamp(1, 60)).ceil(), 60000)
          .toInt(),
      width: base.width.clamp(0, 4096),
      height: base.height.clamp(0, 4096),
      loop: base.loop.clamp(0, 100),
      usePalette: base.usePalette,
      outputDir: outputDir.isEmpty ? null : outputDir,
      formError: null,
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
  /// 装配总输出时长)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    frameDurationMs: state.frameDurationMs,
    width: state.width,
    height: state.height,
    loop: state.loop,
    usePalette: state.usePalette,
  );

  // ---- 生命周期 ----

  /// 提交图片合成任务(多图 → GIF,入任务队列)。
  ///
  /// [paths] 有序图片路径(≥1);[sourceWidth/sourceHeight] 为首图尺寸
  /// (UI 层解码探测,0 = 未知,命令构造据此决定是否统一分辨率)。
  /// 空列表拒绝;重入守卫防连点。
  Future<void> submit(
    List<String> paths, {
    int sourceWidth = 0,
    int sourceHeight = 0,
  }) async {
    if (_submitting) return;
    if (paths.isEmpty) {
      state = state.copyWith(formError: '请先选择图片');
      return;
    }
    _submitting = true;
    try {
      final setting = assembleSetting();
      final id = await ref
          .read(taskQueueControllerProvider.notifier)
          .submitFromImages(
            setting,
            ImageGifSource(
              paths: paths,
              width: sourceWidth,
              height: sourceHeight,
            ),
            outputDir: state.outputDir,
          );
      _activeTaskId = id;
      state = state.copyWith(
        lifecycle: ImageGifLifecycle.exporting,
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
  Future<void> reset() async {
    final task = state.task;
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
    state = state.copyWith(
      lifecycle: ImageGifLifecycle.idle,
      taskId: null,
      task: null,
      errorMessage: null,
    );
  }

  /// 打开输出位置(done 态动作,UI 层仅转发)。
  Future<void> openOutputFolder() async {
    final task = state.task;
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
    final outputPath = state.task?.outputPath;
    if (outputPath == null) return;
    await ref.read(platformAdapterProvider).shareFile(outputPath);
  }

  Future<void> _onTaskEvent(ExportTask task) async {
    final taskId = _activeTaskId;
    if (taskId == null || task.id != taskId) return;
    if (task.state == TaskState.completed) {
      final outputPath = task.outputPath;
      if (outputPath == null) return;
      int size = 0;
      try {
        size = await File(outputPath).length();
      } on FileSystemException {
        // 大小读取失败不阻断完成弹窗
      }
      state = state.copyWith(
        lifecycle: ImageGifLifecycle.done,
        task: task,
        outputSizeBytes: size,
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

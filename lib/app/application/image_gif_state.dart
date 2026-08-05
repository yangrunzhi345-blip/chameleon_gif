import '../../domain/entities/export_task.dart';

/// 图片制作 GIF 会话生命周期态(与 [ExportLifecycle] 同构)。
enum ImageGifLifecycle { idle, exporting, done, failed }

/// 图片制作 GIF 会话状态(app 层跨模块组合,autoDispose)。
///
/// 含生命周期(lifecycle/taskId/task/...)与参数表单(fps/frameDurationMs/
/// width/height/loop/usePalette/outputDir/formError)两部分;高频进度量
/// 不进入本状态,经图片页独立 StreamProvider(200ms 节流)消费。
///
/// 生命周期转换一律经 [copyWith](表单值恒保留);命名构造器仅供初始态
/// 与测试。
class ImageGifFormState {
  const ImageGifFormState._({
    required this.lifecycle,
    this.taskId,
    this.task,
    this.outputSizeBytes,
    this.errorMessage,
    this.fps = 15.0,
    this.frameDurationMs = 1000,
    this.width = 0,
    this.height = 0,
    this.loop = 0,
    this.usePalette = true,
    this.outputDir,
    this.formError,
    this.scaleMultiplier,
  });

  const ImageGifFormState.idle() : this._(lifecycle: ImageGifLifecycle.idle);

  final ImageGifLifecycle lifecycle;

  /// 进行中任务 id(exporting 态)。
  final int? taskId;

  /// 已完成任务(done 态)。
  final ExportTask? task;

  /// 输出文件字节数(done 态;功能层读文件,UI 仅展示)。
  final int? outputSizeBytes;

  /// 会话级错误文案(failed 态)。
  final String? errorMessage;

  // ---- 参数表单(会话内,导出中锁定) ----

  /// 输出帧率(1–60)。
  final double fps;

  /// 每张图片停留时长(毫秒;钳制 [ceil(1000/fps), 60000],否则该图
  /// 在 -t 窗口内 0 帧被 concat 静默跳过)。
  final int frameDurationMs;

  /// 输出宽度(0 = 原图等比;钳制 0–4096)。
  final int width;

  /// 输出高度(0 = 原图等比;钳制 0–4096)。
  final int height;

  /// 循环次数(0 = 无限循环;钳制 0–100)。
  final int loop;

  /// 质量开关:true = 调色板两遍(高质),false = 标准单遍。
  final bool usePalette;

  /// 导出目录(null = 系统临时目录)。
  final String? outputDir;

  /// 表单级错误(时长非法/目录选择失败等;非空时禁用导出)。
  final String? formError;

  /// 等比缩放倍数(null = 宽高被手动指定,回显"自定义";选倍数时
  /// 首图尺寸已知则联动落成具体宽高,未知则仅存偏好)。
  final double? scaleMultiplier;

  /// 未传标记(允许显式置 null:taskId/task/errorMessage/outputDir/formError/
  /// scaleMultiplier)。
  static const _unset = Object();

  ImageGifFormState copyWith({
    ImageGifLifecycle? lifecycle,
    Object? taskId = _unset,
    Object? task = _unset,
    Object? outputSizeBytes = _unset,
    Object? errorMessage = _unset,
    double? fps,
    int? frameDurationMs,
    int? width,
    int? height,
    int? loop,
    bool? usePalette,
    Object? outputDir = _unset,
    Object? formError = _unset,
    Object? scaleMultiplier = _unset,
  }) {
    return ImageGifFormState._(
      lifecycle: lifecycle ?? this.lifecycle,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as int?,
      task: identical(task, _unset) ? this.task : task as ExportTask?,
      outputSizeBytes: identical(outputSizeBytes, _unset)
          ? this.outputSizeBytes
          : outputSizeBytes as int?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      fps: fps ?? this.fps,
      frameDurationMs: frameDurationMs ?? this.frameDurationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      loop: loop ?? this.loop,
      usePalette: usePalette ?? this.usePalette,
      outputDir: identical(outputDir, _unset)
          ? this.outputDir
          : outputDir as String?,
      formError: identical(formError, _unset)
          ? this.formError
          : formError as String?,
      scaleMultiplier: identical(scaleMultiplier, _unset)
          ? this.scaleMultiplier
          : scaleMultiplier as double?,
    );
  }

  /// 导出中锁定:表单更新与导出按钮均拒绝。
  bool get locked => lifecycle == ImageGifLifecycle.exporting;

  /// 每图时长下限(毫秒)= ceil(1000/fps):低于该值该图 0 帧被跳过。
  int get minFrameDurationMs => (1000 / fps).ceil();
}

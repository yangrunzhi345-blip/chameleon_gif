/// 批量导入表单状态(纯 Dart,无生命周期/任务字段)。
///
/// 与 [ExportFormState](features/export/application/export_state.dart) 的
/// 参数表单部分同构,但无 lifecycle/task/outputSizeBytes:批量设置页只
/// 有表单,无单任务导出会话。
class BatchImportFormState {
  const BatchImportFormState._({
    this.fps = 15.0,
    this.width = 0,
    this.height = 0,
    this.loop = 0,
    this.start = Duration.zero,
    this.end,
    this.outputDir,
    this.formError,
    this.scaleMultiplier,
    this.playbackSpeed = 1.0,
  });

  /// 初始态(内置默认:15fps、原图等比、全长、临时目录)。
  const BatchImportFormState.idle() : this._();

  /// 输出帧率(1–60)。
  final double fps;

  /// 输出宽度(0 = 原图等比;钳制 0–4096)。
  final int width;

  /// 输出高度(0 = 原图等比;钳制 0–4096)。
  final int height;

  /// 循环次数(0 = 无限循环;钳制 0–100)。
  final int loop;

  /// 输出起点。
  final Duration start;

  /// 输出终点(null = 到视频结尾,逐文件装配全长)。
  final Duration? end;

  /// 导出目录(null = 系统临时目录)。
  final String? outputDir;

  /// 表单级错误(时间格式非法/目录选择失败等;非空时禁用开始按钮)。
  final String? formError;

  /// 等比缩放倍数(null = 宽高被手动指定,回显"自定义";仅批量/设置页
  /// 无源尺寸语义,选倍数只存偏好,入队时按各文件自身尺寸展开)。
  final double? scaleMultiplier;

  /// 播放速度(0.25–4;1.0 = 正常,<1 慢放,>1 加速;命令侧 setpts)。
  final double playbackSpeed;

  /// 未传标记(允许显式置 null:end/outputDir/formError/scaleMultiplier)。
  static const _unset = Object();

  BatchImportFormState copyWith({
    double? fps,
    int? width,
    int? height,
    int? loop,
    Duration? start,
    Object? end = _unset,
    Object? outputDir = _unset,
    Object? formError = _unset,
    Object? scaleMultiplier = _unset,
    double? playbackSpeed,
  }) {
    return BatchImportFormState._(
      fps: fps ?? this.fps,
      width: width ?? this.width,
      height: height ?? this.height,
      loop: loop ?? this.loop,
      start: start ?? this.start,
      end: identical(end, _unset) ? this.end : end as Duration?,
      outputDir: identical(outputDir, _unset)
          ? this.outputDir
          : outputDir as String?,
      formError: identical(formError, _unset)
          ? this.formError
          : formError as String?,
      scaleMultiplier: identical(scaleMultiplier, _unset)
          ? this.scaleMultiplier
          : scaleMultiplier as double?,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

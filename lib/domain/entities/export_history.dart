import '../value_objects/gif_setting.dart';

/// 转换历史领域实体(不可变快照,字段契约见 docs/07-数据库设计.md §7.3.2)。
///
/// 转换完成时生成,仅读/删;重转基于 settings 快照回填参数。
class ExportHistory {
  const ExportHistory({
    required this.id,
    required this.videoPath,
    required this.outputPath,
    required this.settings,
    required this.durationMs,
    required this.outputSizeBytes,
    required this.createdAt,
    required this.sourceDurationMs,
    this.outputFrameCount,
  });

  final int id;
  final String videoPath;
  final String outputPath;
  final GifSetting settings;

  /// 转码耗时(ms)
  final int durationMs;

  /// 输出文件大小(字节)
  final int outputSizeBytes;

  /// 完成时间
  final DateTime createdAt;

  /// 源视频时长(ms)
  final int sourceDurationMs;

  /// 输出帧数(可空)
  final int? outputFrameCount;
}

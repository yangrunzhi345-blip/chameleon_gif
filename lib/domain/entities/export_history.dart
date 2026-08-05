import '../value_objects/gif_setting.dart';
import '../value_objects/per_image_control.dart';

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
    this.imagePaths,
    this.perImageControls,
  });

  final int id;

  /// 源路径:视频模式 = 视频文件路径;图片模式 = 首图路径。
  final String videoPath;

  final String outputPath;
  final GifSetting settings;

  /// 图片模式:有序图片路径列表;null = 视频模式(重转分支依据)。
  final List<String>? imagePaths;

  /// 图片模式:每图精细化控制快照(与 imagePaths 等长对齐,null = 全部默认;
  /// 重转时回填,保证原参数可复现)。
  final List<PerImageControl>? perImageControls;

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

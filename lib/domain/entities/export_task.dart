import '../value_objects/gif_setting.dart';
import '../value_objects/task_state.dart';
import '../../shared/platform/gallery_save_result.dart';

/// 转换任务领域实体(字段契约见 docs/07-数据库设计.md §7.3.1)。
///
/// 状态机:queued→running→(completed|failed|cancelled),见 docs/06 §6.3。
/// Isar 持久化映射见 shared/repositories/schemas/export_task_schema.dart。
class ExportTask {
  const ExportTask({
    required this.id,
    required this.videoPath,
    required this.settings,
    required this.state,
    required this.createdAt,
    this.outputPath,
    this.progress = 0,
    this.errorCode,
    this.errorDetail,
    this.retryCount = 0,
    this.startedAt,
    this.finishedAt,
    this.galleryStatus = GallerySaveStatus.unsupported,
    this.galleryPath,
    this.galleryUri,
    this.galleryMessage,
    this.imagePaths,
  });

  /// 自增主键(未持久化时可为 0)
  final int id;

  /// 源路径:视频模式 = 视频文件路径;图片模式 = 首图路径
  /// (输出命名/galleryDisplayName 复用该字段,零改动)。
  final String videoPath;

  /// 图片模式:有序图片路径列表;null = 视频模式。
  final List<String>? imagePaths;
  final String? outputPath;
  final GifSetting settings;

  /// 当前状态
  final TaskState state;

  /// 进度 0.0–1.0
  final double progress;
  final String? errorCode;
  final String? errorDetail;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// 完成时保存到系统相册的结果状态(默认 unsupported = 桌面等无相册能力)。
  final GallerySaveStatus galleryStatus;

  /// 相册内展示路径(如 `Pictures/GIFForge/demo.gif`,仅 saved 时非空)。
  final String? galleryPath;

  /// 相册条目 content URI(仅 saved 时非空,"打开相册"定位用)。
  final String? galleryUri;

  /// 保存失败的用户可读中文提示(仅 failed 时非空)。
  final String? galleryMessage;

  /// 派生副本(供状态机推进时使用,字段级复制)。
  ///
  /// 注意:`null` 参数为"保持原值"语义,**无法置空可空字段**(errorCode/
  /// errorDetail/outputPath 等);需置空时显式构造新实体。
  ExportTask copyWith({
    String? outputPath,
    GifSetting? settings,
    TaskState? state,
    double? progress,
    String? errorCode,
    String? errorDetail,
    int? retryCount,
    DateTime? startedAt,
    DateTime? finishedAt,
    GallerySaveStatus? galleryStatus,
    String? galleryPath,
    String? galleryUri,
    String? galleryMessage,
    List<String>? imagePaths,
  }) {
    return ExportTask(
      id: id,
      videoPath: videoPath,
      outputPath: outputPath ?? this.outputPath,
      settings: settings ?? this.settings,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorCode: errorCode ?? this.errorCode,
      errorDetail: errorDetail ?? this.errorDetail,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      galleryStatus: galleryStatus ?? this.galleryStatus,
      galleryPath: galleryPath ?? this.galleryPath,
      galleryUri: galleryUri ?? this.galleryUri,
      galleryMessage: galleryMessage ?? this.galleryMessage,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}

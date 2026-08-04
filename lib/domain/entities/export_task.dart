import '../value_objects/gif_setting.dart';
import '../value_objects/task_state.dart';

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
  });

  /// 自增主键(未持久化时可为 0)
  final int id;
  final String videoPath;
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

  /// 派生副本(供状态机推进时使用,字段级复制)
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
    );
  }
}

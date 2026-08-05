import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../platform/gallery_save_result.dart';

part 'export_task_schema.g.dart';

/// ExportTask 的 Isar 持久化映射(docs/07-数据库设计.md §7.3.1)。
///
/// 领域实体 ↔ 集合转换由仓储实现负责(P5 落地):
/// settings 以 JSON 字符串存储(Freezed toJson)。
@collection
class ExportTaskSchema {
  Id id = Isar.autoIncrement;

  late String videoPath;

  String? outputPath;

  /// GifSetting 的 JSON 快照
  late String settingsJson;

  /// TaskState.index
  @Index()
  late int state;

  double progress = 0;

  String? errorCode;

  String? errorDetail;

  int retryCount = 0;

  @Index()
  late DateTime createdAt;

  DateTime? startedAt;

  DateTime? finishedAt;

  /// GallerySaveStatus.index(默认 0 = unsupported)
  int galleryStatus = 0;

  String? galleryPath;

  String? galleryUri;

  String? galleryMessage;

  /// 图片模式图片路径列表的 JSON 编码(null = 视频模式)。
  /// Isar 3.x 无原生 List 列,仿 settingsJson 用 JSON 字符串列。
  String? imagePathsJson;

  /// 领域实体 → 集合
  static ExportTaskSchema fromEntity(ExportTask task) {
    final schema = ExportTaskSchema()
      ..id = task.id
      ..videoPath = task.videoPath
      ..outputPath = task.outputPath
      ..settingsJson = jsonEncode(task.settings.toJson())
      ..state = task.state.index
      ..progress = task.progress
      ..errorCode = task.errorCode
      ..errorDetail = task.errorDetail
      ..retryCount = task.retryCount
      ..createdAt = task.createdAt
      ..startedAt = task.startedAt
      ..finishedAt = task.finishedAt
      ..galleryStatus = task.galleryStatus.index
      ..galleryPath = task.galleryPath
      ..galleryUri = task.galleryUri
      ..galleryMessage = task.galleryMessage
      ..imagePathsJson = task.imagePaths == null
          ? null
          : jsonEncode(task.imagePaths);
    return schema;
  }

  /// 集合 → 领域实体(JSON 解析失败时抛出,由仓储层处理)
  ExportTask toEntity() {
    return ExportTask(
      id: id,
      videoPath: videoPath,
      outputPath: outputPath,
      settings: GifSetting.fromJson(
        Map<String, dynamic>.from(
          const JsonDecoder().convert(settingsJson) as Map,
        ),
      ),
      state: TaskState.values[state],
      progress: progress,
      errorCode: errorCode,
      errorDetail: errorDetail,
      retryCount: retryCount,
      createdAt: createdAt,
      startedAt: startedAt,
      finishedAt: finishedAt,
      galleryStatus: GallerySaveStatus.values[galleryStatus],
      galleryPath: galleryPath,
      galleryUri: galleryUri,
      galleryMessage: galleryMessage,
      imagePaths: imagePathsJson == null
          ? null
          : (const JsonDecoder().convert(imagePathsJson!) as List)
                .cast<String>(),
    );
  }
}

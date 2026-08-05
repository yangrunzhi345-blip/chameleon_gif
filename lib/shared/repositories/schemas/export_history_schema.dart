import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../domain/entities/export_history.dart';
import '../../../domain/value_objects/gif_setting.dart';

part 'export_history_schema.g.dart';

/// ExportHistory 的 Isar 持久化映射(docs/07-数据库设计.md §7.3.2)。
@collection
class ExportHistorySchema {
  Id id = Isar.autoIncrement;

  late String videoPath;

  late String outputPath;

  /// GifSetting 的 JSON 快照
  late String settingsJson;

  late int durationMs;

  late int outputSizeBytes;

  @Index()
  late DateTime createdAt;

  late int sourceDurationMs;

  int? outputFrameCount;

  /// 图片模式图片路径列表的 JSON 编码(null = 视频模式)。
  String? imagePathsJson;

  static ExportHistorySchema fromEntity(ExportHistory history) {
    final schema = ExportHistorySchema()
      ..id = history.id
      ..videoPath = history.videoPath
      ..outputPath = history.outputPath
      ..settingsJson = jsonEncode(history.settings.toJson())
      ..durationMs = history.durationMs
      ..outputSizeBytes = history.outputSizeBytes
      ..createdAt = history.createdAt
      ..sourceDurationMs = history.sourceDurationMs
      ..outputFrameCount = history.outputFrameCount
      ..imagePathsJson = history.imagePaths == null
          ? null
          : jsonEncode(history.imagePaths);
    return schema;
  }

  ExportHistory toEntity() {
    return ExportHistory(
      id: id,
      videoPath: videoPath,
      outputPath: outputPath,
      settings: GifSetting.fromJson(
        Map<String, dynamic>.from(
          const JsonDecoder().convert(settingsJson) as Map,
        ),
      ),
      durationMs: durationMs,
      outputSizeBytes: outputSizeBytes,
      createdAt: createdAt,
      sourceDurationMs: sourceDurationMs,
      outputFrameCount: outputFrameCount,
      imagePaths: imagePathsJson == null
          ? null
          : (const JsonDecoder().convert(imagePathsJson!) as List)
                .cast<String>(),
    );
  }
}

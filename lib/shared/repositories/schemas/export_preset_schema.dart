import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../../../domain/entities/export_preset.dart';
import '../../../domain/value_objects/gif_setting.dart';

part 'export_preset_schema.g.dart';

/// ExportPreset 的 Isar 持久化映射(docs/07-数据库设计.md §7.3.3)。
@collection
class ExportPresetSchema {
  Id id = Isar.autoIncrement;

  late String name;

  /// GifSetting 的 JSON 快照
  late String settingsJson;

  late DateTime createdAt;

  static ExportPresetSchema fromEntity(ExportPreset preset) {
    final schema = ExportPresetSchema()
      ..id = preset.id
      ..name = preset.name
      ..settingsJson = preset.settings.toJson().toString()
      ..createdAt = preset.createdAt;
    return schema;
  }

  ExportPreset toEntity() {
    return ExportPreset(
      id: id,
      name: name,
      settings: GifSetting.fromJson(
        Map<String, dynamic>.from(
          const JsonDecoder().convert(settingsJson) as Map,
        ),
      ),
      createdAt: createdAt,
    );
  }
}

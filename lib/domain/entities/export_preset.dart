import '../value_objects/gif_setting.dart';

/// 导出预设(可复用模板,字段契约见 docs/07-数据库设计.md §7.3.3)。
class ExportPreset {
  const ExportPreset({
    required this.id,
    required this.name,
    required this.settings,
    required this.createdAt,
  });

  final int id;
  final String name;
  final GifSetting settings;
  final DateTime createdAt;
}

import '../value_objects/app_theme_mode.dart';
import '../value_objects/gif_setting.dart';

/// 偏好设置仓储(SharedPreferences 实现,见 docs/07-数据库设计.md §7.1)。
///
/// 仅存"小而高频读"的偏好;结构化数据(Task/History/Preset)走 Isar。
/// 主题使用领域自有枚举 [AppThemeMode](domain 不依赖 Flutter)。
abstract interface class SettingsRepository {
  // ---- 外观 ----

  AppThemeMode get themeMode;

  Future<void> setThemeMode(AppThemeMode mode);

  String get language;

  Future<void> setLanguage(String language);

  // ---- 路径 ----

  /// 最近一次导入目录(文件选择器初始目录)
  String? get lastImportDir;

  Future<void> setLastImportDir(String path);

  /// 默认导出目录
  String get defaultExportDir;

  Future<void> setDefaultExportDir(String path);

  // ---- 默认参数 ----

  /// 默认 GIF 参数(未设置时返回 null,由调用方应用内置默认)
  GifSetting? get defaultGifSetting;

  Future<void> setDefaultGifSetting(GifSetting setting);
}

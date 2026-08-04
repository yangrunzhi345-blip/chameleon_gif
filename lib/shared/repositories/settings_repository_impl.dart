import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repository_interfaces/settings_repository.dart';
import '../../domain/value_objects/app_theme_mode.dart';
import '../../domain/value_objects/gif_setting.dart';

/// SettingsRepository 的 SharedPreferences 实现。
///
/// Key 约定见 docs/07-数据库设计.md §7.3.4;损坏值容错(返回默认值)。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'theme_mode';
  static const _kLanguage = 'language';
  static const _kLastImportDir = 'last_import_dir';
  static const _kDefaultExportDir = 'default_export_dir';
  static const _kDefaultGifSetting = 'default_gif_setting';

  static const _kThemeSystem = 'system';

  @override
  AppThemeMode get themeMode {
    switch (_prefs.getString(_kThemeMode) ?? _kThemeSystem) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  @override
  String get language => _prefs.getString(_kLanguage) ?? 'system';

  @override
  Future<void> setLanguage(String language) =>
      _prefs.setString(_kLanguage, language);

  @override
  String? get lastImportDir => _prefs.getString(_kLastImportDir);

  @override
  Future<void> setLastImportDir(String path) =>
      _prefs.setString(_kLastImportDir, path);

  @override
  String get defaultExportDir =>
      _prefs.getString(_kDefaultExportDir) ?? _kDefaultExportDirFallback;

  @override
  Future<void> setDefaultExportDir(String path) =>
      _prefs.setString(_kDefaultExportDir, path);

  @override
  GifSetting? get defaultGifSetting {
    final raw = _prefs.getString(_kDefaultGifSetting);
    if (raw == null) return null;
    try {
      return GifSetting.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> setDefaultGifSetting(GifSetting setting) =>
      _prefs.setString(_kDefaultGifSetting, jsonEncode(setting.toJson()));

  /// 默认导出目录:用户 Downloads 目录(桌面)/空串由调用方按平台处理
  static const _kDefaultExportDirFallback = '';
}

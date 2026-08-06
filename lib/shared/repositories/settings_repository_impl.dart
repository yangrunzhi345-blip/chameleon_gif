import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repository_interfaces/settings_repository.dart';
import '../../domain/value_objects/app_theme_mode.dart';
import '../../domain/value_objects/capture_params.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../domain/value_objects/record_params.dart';

/// SettingsRepository 的 SharedPreferences 实现。
///
/// Key 约定见 docs/07-数据库设计.md §7.3.4;损坏值容错(返回默认值)。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  // ---- SharedPreferences 存储键 ----
  static const _themeModeKey = 'theme_mode';
  static const _languageKey = 'language';
  static const _lastImportDirKey = 'last_import_dir';
  static const _defaultExportDirKey = 'default_export_dir';
  static const _defaultGifSettingKey = 'default_gif_setting';
  static const _captureParamsKey = 'capture_params';
  static const _captureDeviceIdKey = 'capture_device_id';
  static const _recordParamsKey = 'record_params';

  // ---- 键值/默认值 ----
  static const _themeSystemValue = 'system';

  @override
  AppThemeMode get themeMode {
    switch (_prefs.getString(_themeModeKey) ?? _themeSystemValue) {
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
      _prefs.setString(_themeModeKey, mode.name);

  @override
  String get language => _prefs.getString(_languageKey) ?? 'system';

  @override
  Future<void> setLanguage(String language) =>
      _prefs.setString(_languageKey, language);

  @override
  String? get lastImportDir => _prefs.getString(_lastImportDirKey);

  @override
  Future<void> setLastImportDir(String path) =>
      _prefs.setString(_lastImportDirKey, path);

  @override
  String get defaultExportDir =>
      _prefs.getString(_defaultExportDirKey) ?? _defaultExportDirKeyFallback;

  @override
  Future<void> setDefaultExportDir(String path) =>
      _prefs.setString(_defaultExportDirKey, path);

  @override
  GifSetting? get defaultGifSetting {
    final raw = _prefs.getString(_defaultGifSettingKey);
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
      _prefs.setString(_defaultGifSettingKey, jsonEncode(setting.toJson()));

  @override
  CaptureParams? get captureParams {
    final raw = _prefs.getString(_captureParamsKey);
    if (raw == null) return null;
    try {
      return CaptureParams.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return null; // 损坏值容错:按未设置处理
    }
  }

  @override
  Future<void> setCaptureParams(CaptureParams params) =>
      _prefs.setString(_captureParamsKey, jsonEncode(params.toJson()));

  @override
  String get captureDeviceId => _prefs.getString(_captureDeviceIdKey) ?? 'back';

  @override
  Future<void> setCaptureDeviceId(String deviceId) =>
      _prefs.setString(_captureDeviceIdKey, deviceId);

  @override
  RecordParams? get recordParams {
    final raw = _prefs.getString(_recordParamsKey);
    if (raw == null) return null;
    try {
      return RecordParams.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      return null; // 损坏值容错
    }
  }

  @override
  Future<void> setRecordParams(RecordParams params) =>
      _prefs.setString(_recordParamsKey, jsonEncode(params.toJson()));

  /// 默认导出目录:用户 Downloads 目录(桌面)/空串由调用方按平台处理
  static const _defaultExportDirKeyFallback = '';
}

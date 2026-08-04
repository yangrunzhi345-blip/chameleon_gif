import 'package:chameleon_gif/domain/repository_interfaces/settings_repository.dart';
import 'package:chameleon_gif/domain/value_objects/app_theme_mode.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';

/// 内存版 SettingsRepository(theme_controller 等测试用)。
///
/// 记录最近一次主题持久化调用 [lastSetThemeMode],便于断言"状态切换 +
/// 持久化"两件事都发生;其余字段取惰性默认值。
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.themeMode = AppThemeMode.system});

  @override
  AppThemeMode themeMode;

  /// 最近一次 [setThemeMode] 收到的值(未调用为 null)。
  AppThemeMode? lastSetThemeMode;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    themeMode = mode;
    lastSetThemeMode = mode;
  }

  @override
  String get language => 'system';

  @override
  Future<void> setLanguage(String language) async {}

  @override
  String? get lastImportDir => null;

  @override
  Future<void> setLastImportDir(String path) async {}

  @override
  String get defaultExportDir => '';

  @override
  Future<void> setDefaultExportDir(String path) async {}

  @override
  GifSetting? get defaultGifSetting => null;

  @override
  Future<void> setDefaultGifSetting(GifSetting setting) async {}
}

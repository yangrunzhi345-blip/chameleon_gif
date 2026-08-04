import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/app_theme_mode.dart';
import '../../shared/providers/core_providers.dart';

/// 主题控制器(功能层,纯 Dart,不依赖 Widget/Flutter)。
///
/// 三态(浅/深/跟随系统)经 SettingsRepository 持久化,状态为领域枚举
/// [AppThemeMode];映射为 Flutter `ThemeMode` 收敛于 UI 层(app.dart)。
class ThemeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.themeMode;
  }

  void setThemeMode(AppThemeMode mode) {
    state = mode;
    ref.read(settingsRepositoryProvider).setThemeMode(mode);
  }
}

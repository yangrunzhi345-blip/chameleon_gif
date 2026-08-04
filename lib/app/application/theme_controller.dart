import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/core_providers.dart';

/// 主题控制器(功能层,纯 Dart,不依赖 Widget)。
///
/// 三态(浅/深/跟随系统)经 SettingsRepository 持久化,
/// 详见 docs/09-状态管理.md §9.2 与 docs/10-UI设计.md §10.4。
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.themeMode;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref.read(settingsRepositoryProvider).setThemeMode(mode);
  }
}

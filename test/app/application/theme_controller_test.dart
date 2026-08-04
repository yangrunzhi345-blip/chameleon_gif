import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/app/application/providers.dart';
import 'package:gif_forge/domain/value_objects/app_theme_mode.dart';
import 'package:gif_forge/shared/providers/core_providers.dart';
import 'package:gif_forge/shared/repositories/settings_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_settings_repository.dart';

void main() {
  group('ThemeController', () {
    test('build 读取仓储初值', () {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(themeMode: AppThemeMode.light),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.light);
    });

    test('setThemeMode:状态切换 + 持久化调用同时发生', () {
      final repo = FakeSettingsRepository(themeMode: AppThemeMode.system);
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      container
          .read(themeModeProvider.notifier)
          .setThemeMode(AppThemeMode.dark);

      expect(container.read(themeModeProvider), AppThemeMode.dark);
      expect(repo.lastSetThemeMode, AppThemeMode.dark);
      expect(repo.themeMode, AppThemeMode.dark);
    });

    test('三态循环切换', () {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(themeMode: AppThemeMode.system),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(themeModeProvider.notifier);

      notifier.setThemeMode(AppThemeMode.light);
      expect(container.read(themeModeProvider), AppThemeMode.light);
      notifier.setThemeMode(AppThemeMode.dark);
      expect(container.read(themeModeProvider), AppThemeMode.dark);
      notifier.setThemeMode(AppThemeMode.system);
      expect(container.read(themeModeProvider), AppThemeMode.system);
    });

    test('持久化非法值回退 system(真实 SharedPrefs 仓储)', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'banana'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            SharedPrefsSettingsRepository(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.system);
    });

    test('持久化 dark 生效(真实 SharedPrefs 仓储)', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            SharedPrefsSettingsRepository(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });
  });
}

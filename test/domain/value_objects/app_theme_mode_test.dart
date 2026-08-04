import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/value_objects/app_theme_mode.dart';

void main() {
  group('AppThemeMode', () {
    test('三态齐备且序稳定(持久化契约)', () {
      expect(AppThemeMode.values, [
        AppThemeMode.light,
        AppThemeMode.dark,
        AppThemeMode.system,
      ]);
    });

    test('name 与 SharedPreferences 字符串键契约一致', () {
      expect(AppThemeMode.light.name, 'light');
      expect(AppThemeMode.dark.name, 'dark');
      expect(AppThemeMode.system.name, 'system');
    });
  });
}

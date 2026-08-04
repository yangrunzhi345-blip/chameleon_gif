import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/app/app.dart';
import 'package:gif_forge/shared/providers/core_providers.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P0 冒烟:应用启动 → 渲染主页 → 主题切换生效且持久化。
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: const GifForgeApp(),
    );
  }

  testWidgets('启动渲染主页并支持主题三态切换', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('GifForge'), findsWidgets);

    // 切换到深色
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    // 切换到浅色
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/value_objects/app_theme_mode.dart';
import 'application/providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// 应用根组件(MaterialApp + 路由 + 主题三态)。
///
/// 运行时依赖(isar/prefs/logger)由 main() 经 ProviderScope overrides 注入,
/// 本组件只做组装,不含业务逻辑。
/// [router] 可注入独立实例(测试隔离;默认全局单例 [appRouter])。
/// 领域枚举 → Flutter ThemeMode 的映射收敛于此(UI 层)。
class GifForgeApp extends ConsumerWidget {
  const GifForgeApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'GifForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (appThemeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router ?? appRouter,
    );
  }
}

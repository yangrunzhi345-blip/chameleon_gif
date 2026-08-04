import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// 应用根组件(MaterialApp + 路由 + 主题三态)。
///
/// 运行时依赖(isar/prefs/logger)由 main() 经 ProviderScope overrides 注入,
/// 本组件只做组装,不含业务逻辑。
class GifForgeApp extends ConsumerWidget {
  const GifForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'GifForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}

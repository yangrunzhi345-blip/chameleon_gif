import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/value_objects/app_theme_mode.dart';
import '../features/task_queue/application/task_queue_providers.dart';
import 'application/providers.dart';
import 'presentation/batch_completion_host.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// 应用根组件(MaterialApp + 路由 + 主题三态)。
///
/// 运行时依赖(isar/prefs/logger)由 main() 经 ProviderScope overrides 注入,
/// 本组件只做组装,不含业务逻辑。
/// [router] 可注入独立实例(测试隔离;默认全局单例 [appRouter])。
/// 领域枚举 → Flutter ThemeMode 的映射收敛于此(UI 层)。
class ChameleonGifApp extends ConsumerWidget {
  const ChameleonGifApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeModeProvider);
    // 启动即物化任务队列控制器:触发 TaskManager.start() 崩溃恢复扫描
    // (kill 进程重启后 queued/running 任务重新排队,不依赖打开队列页)
    ref.watch(taskQueueControllerProvider);
    return MaterialApp.router(
      title: 'Chameleon Gif',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (appThemeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router ?? appRouter,
      // 批量完成弹窗宿主(全局常驻,任何页面之上任务落定都弹窗)
      builder: (context, child) =>
          BatchCompletionHost(child: child ?? const SizedBox.shrink()),
    );
  }
}

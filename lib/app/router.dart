import 'package:go_router/go_router.dart';

import '../../domain/entities/video_info.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/task_queue/presentation/queue_page.dart';
import 'presentation/batch_import_screen.dart';
import 'presentation/home_page.dart';
import 'presentation/preview_screen.dart';
import 'presentation/settings_screen.dart';

/// 路由表构建(供 [appRouter] 与测试注入独立实例复用)。
List<RouteBase> buildRoutes() => [
  GoRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const HomePage(),
  ),
  GoRoute(
    path: '/preview',
    name: 'preview',
    builder: (context, state) {
      // 安全 cast:go_router 17 在 Router 恢复路径会对 extra 做 JSON 编解码
      // (复杂对象会还原为 Map),非 VideoInfo(恢复/深链)时预览页自行回退。
      final video = state.extra;
      return PreviewScreen(video: video is VideoInfo ? video : null);
    },
  ),
  GoRoute(
    path: '/batch-import',
    name: 'batch-import',
    builder: (context, state) {
      // List<String> 为 JSON 基础类型,恢复路径安全;非 List<String>
      // (恢复/深链)时设置页自行回退。
      final extra = state.extra;
      return BatchImportScreen(paths: extra is List<String> ? extra : null);
    },
  ),
  GoRoute(
    path: '/history',
    name: 'history',
    builder: (context, state) => const HistoryPage(),
  ),
  GoRoute(
    path: '/queue',
    name: 'queue',
    builder: (context, state) => const QueuePage(),
  ),
  GoRoute(
    path: '/settings',
    name: 'settings',
    builder: (context, state) => const SettingsScreen(),
  ),
];

/// 全局路由表(声明式,见 docs/09-状态管理.md 与 docs/10-UI设计.md)。
/// 全局单例;测试经 [ChameleonGifApp.router] 注入独立实例避免栈状态串扰。
final appRouter = GoRouter(routes: buildRoutes());

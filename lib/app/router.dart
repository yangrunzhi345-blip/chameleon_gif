import 'package:go_router/go_router.dart';

import 'presentation/home_page.dart';

/// 全局路由表(声明式,见 docs/09-状态管理.md 与 docs/10-UI设计.md)。
///
/// MVP 仅主页一条路由;功能页面(P2 预览/P4 参数/P5 历史)按阶段追加。
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/preview/presentation/completed_gif_preview_screen.dart';
import 'package:chameleon_gif/features/preview/presentation/video_preview_panel.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/fake_player_port.dart';

/// 预览完成 GIF 页:首项自动加载、列表切换播放/高亮、错误态无返回按钮。
///
/// 注入 FakePlayerPort(renderHandle 非 Player → 面板降级占位,不触 FFI)。
void main() {
  const paths = ['/tmp/out/a.gif', '/tmp/out/b.gif'];

  late FakePlayerPort port;
  late GoRouter router;

  Widget wrap({List<String>? paths}) {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home-stub')),
        ),
        GoRoute(
          path: '/preview-complete',
          builder: (_, state) =>
              CompletedGifPreviewScreen(paths: paths ?? const <String>[]),
        ),
      ],
    );
    return ProviderScope(
      overrides: [previewPlayerPortProvider.overrideWithValue(port)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  setUp(() {
    port = FakePlayerPort();
  });

  Future<void> enter(WidgetTester tester, List<String> extra) async {
    await tester.pumpWidget(wrap(paths: extra));
    router.push('/preview-complete', extra: extra);
    await tester.pumpAndSettle();
  }

  testWidgets('首项自动加载并选中高亮', (tester) async {
    await enter(tester, paths);

    expect(port.openedPath, '/tmp/out/a.gif', reason: '进入页面自动播放首项');
    final first = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'a.gif'),
    );
    expect(first.selected, isTrue, reason: '当前播放项高亮');
  });

  testWidgets('点击列表项切换播放并移动高亮', (tester) async {
    await enter(tester, paths);

    await tester.tap(find.widgetWithText(ListTile, 'b.gif'));
    await tester.pumpAndSettle();

    expect(port.openedPath, '/tmp/out/b.gif', reason: '切换后打开新 GIF');
    final first = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'a.gif'),
    );
    final second = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'b.gif'),
    );
    expect(first.selected, isFalse);
    expect(second.selected, isTrue, reason: '高亮跟随当前项');
  });

  testWidgets('播放失败 → 错误视图且无"返回"按钮(列表切换兜底)', (tester) async {
    port.openError = StateError('boom');
    await enter(tester, paths);

    expect(find.byType(VideoPreviewPanel), findsOneWidget, reason: '错误态不退出整页');
    expect(find.text('视频加载失败,请尝试其他文件'), findsOneWidget);
    expect(find.text('返回'), findsNothing, reason: '隐藏返回按钮');
    // 列表仍可切换其他 GIF
    await tester.tap(find.widgetWithText(ListTile, 'b.gif'));
    await tester.pumpAndSettle();
    expect(port.openedPath, '/tmp/out/b.gif');
  });

  testWidgets('paths 为空 → 回退返回(不加载)', (tester) async {
    await enter(tester, const []);

    // 页面回退到 home,未加载任何 GIF
    expect(find.text('home-stub'), findsOneWidget);
    expect(port.openedPath, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/features/preview/application/gif_preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_state.dart';
import 'package:chameleon_gif/features/preview/presentation/completed_gif_preview_screen.dart';
import 'package:go_router/go_router.dart';

/// 预览完成 GIF 页:首项自动加载、列表切换/高亮、错误态无返回按钮。
///
/// 注入假控制器(load 同步完成,不触文件 IO/解码/定时器),专注 UI 交互;
/// 无 pending timer(autoDispose 保活由页面 watch 承担)。
class _FakeGifController extends GifPreviewController {
  _FakeGifController(this.opened, {this.failLoad = false});

  final List<String> opened;
  final bool failLoad;

  @override
  Future<void> load(VideoInfo video) async {
    opened.add(video.path);
    state = failLoad
        ? PreviewState.error(
            errorCode: 'GIF_PLAY_OPEN_FAILED',
            errorMessage: 'GIF 加载失败,请尝试其他文件',
            video: video,
          )
        : PreviewState.ready(video, isPlaying: true);
  }
}

void main() {
  const paths = ['/tmp/out/a.gif', '/tmp/out/b.gif'];

  late GoRouter router;

  Widget wrap({
    List<String>? paths,
    List<String>? opened,
    bool failLoad = false,
  }) {
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
      overrides: [
        gifPreviewControllerProvider.overrideWith(
          () => _FakeGifController(opened ?? [], failLoad: failLoad),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> enter(
    WidgetTester tester, {
    List<String> extra = paths,
    List<String>? opened,
    bool failLoad = false,
  }) async {
    await tester.pumpWidget(
      wrap(paths: extra, opened: opened, failLoad: failLoad),
    );
    router.push('/preview-complete', extra: extra);
    await tester.pump(); // 路由切换
    await tester.pump(); // initState microtask 触发 _select
  }

  testWidgets('首项自动加载并选中高亮', (tester) async {
    final opened = <String>[];
    await enter(tester, opened: opened);

    expect(opened, ['/tmp/out/a.gif'], reason: '进入页面自动播放首项');
    final first = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'a.gif'),
    );
    expect(first.selected, isTrue, reason: '当前播放项高亮');
  });

  testWidgets('点击列表项切换播放并移动高亮', (tester) async {
    final opened = <String>[];
    await enter(tester, opened: opened);

    await tester.tap(find.widgetWithText(ListTile, 'b.gif'));
    await tester.pump();

    expect(opened, ['/tmp/out/a.gif', '/tmp/out/b.gif'], reason: '切换后打开新 GIF');
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
    await enter(tester, failLoad: true);

    expect(find.text('GIF 加载失败,请尝试其他文件'), findsOneWidget);
    expect(find.text('返回'), findsNothing, reason: '隐藏返回按钮');
    // 列表仍可切换其他 GIF
    await tester.tap(find.widgetWithText(ListTile, 'b.gif'));
    await tester.pump();
    final second = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'b.gif'),
    );
    expect(second.selected, isTrue, reason: '错误态下仍可切换');
  });

  testWidgets('paths 为空 → 回退返回(不加载)', (tester) async {
    final opened = <String>[];
    await enter(tester, extra: const [], opened: opened);

    // 页面回退到 home
    expect(find.text('home-stub'), findsOneWidget);
    expect(opened, isEmpty);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/image_gif_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/features/export/presentation/export_complete_dialog.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/fake_image_probe_port.dart';
import '../../fixtures/fake_player_port.dart';

/// 图片制作 GIF 页测试:路由/列表操作/表单联动/完整转换流。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;
  late _FakeImagePickPort pickPort;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_img_');
    pickPort = _FakeImagePickPort();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  (Widget, GoRouter, FakeFfmpegService) buildApp({FakeFfmpegService? service}) {
    final svc = service ?? FakeFfmpegService(writeOutput: false);
    final router = GoRouter(routes: buildRoutes());
    final app = ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(pickPort),
        // 探测端口:测试路径的图片文件不存在,注入 Fake 避免 formError 拦截
        imageProbePortProvider.overrideWithValue(
          FakeImageProbePort(width: 64, height: 64),
        ),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(_ImgAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(svc),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: svc,
            platformAdapter: _ImgAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: ChameleonGifApp(router: router),
    );
    return (app, router, svc);
  }

  Future<void> enterScreen(WidgetTester tester, GoRouter router) async {
    unawaited(router.push('/image-gif', extra: ['/img/a.png', '/img/b.png']));
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// 推进真实异步(workDir 创建等 IO)后 settle 渲染。
  Future<void> settleRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('路由可达:列表渲染文件名与顺序', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    expect(find.byType(ImageGifScreen), findsOneWidget);
    expect(find.text('a.png'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
    expect(find.textContaining('共 2 张'), findsOneWidget);
  });

  testWidgets('路由 extra 为 null(恢复/深链)→ 返回主页', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    unawaited(router.push('/image-gif'));
    await tester.pumpAndSettle();

    expect(find.byType(ImageGifScreen), findsNothing);
  });

  testWidgets('缩放倍数:选 2 倍 → 首图 64×64 联动 128×128', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 默认 1 倍收起;展开菜单选 2 倍
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();

    // 宽度/高度回显联动值(64×64 × 2 = 128×128)
    expect(find.text('128 px'), findsNWidgets(2), reason: '宽度与高度均 128');
    expect(find.text('2 倍'), findsOneWidget, reason: '倍数回显 2 倍');
  });

  testWidgets('自定义宽度:菜单"自定义" → 输入 150 → 回显 150 px', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 展开宽度菜单(收起显示"原图等比"),点"自定义"
    await tester.tap(find.text('原图等比').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '150',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('150 px'), findsOneWidget, reason: '非选项值回显具体像素');
    expect(find.text('自定义'), findsOneWidget, reason: '手动宽高 → 倍数回显自定义');
  });

  testWidgets('上移/删除调整列表顺序', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 上移第二张图(a.png 与 b.png 交换)
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'b.png'),
        matching: find.byIcon(Icons.arrow_upward),
      ),
    );
    await tester.pump();
    // ListTile 顺序:先 b 后 a(检查渲染顺序;忽略 SwitchListTile 的标题)
    final tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .where((d) => d != null && d.endsWith('.png'))
        .toList();
    expect(tiles, ['b.png', 'a.png']);

    // 删除第二张(现为 a.png)→ 只剩 b.png
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    expect(find.text('a.png'), findsNothing);
    expect(find.textContaining('共 1 张'), findsOneWidget);
  });

  testWidgets('下移:位于上移左侧,末项禁用', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 第一张(a.png)的下移按钮 → 与 b.png 交换
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.arrow_downward),
      ),
    );
    await tester.pump();
    final tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .where((d) => d != null && d.endsWith('.png'))
        .toList();
    expect(tiles, ['b.png', 'a.png'], reason: '下移第一张与第二张交换');

    // 末项(a.png)下移按钮禁用
    final downBtn = tester.widget<IconButton>(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.widgetWithIcon(IconButton, Icons.arrow_downward),
      ),
    );
    expect(downBtn.onPressed, isNull, reason: '末项下移禁用');

    // 按钮位置:下移在上移左侧
    final downPos = tester
        .getCenter(
          find.descendant(
            of: find.widgetWithText(ListTile, 'b.png'),
            matching: find.byIcon(Icons.arrow_downward),
          ),
        )
        .dx;
    final upPos = tester
        .getCenter(
          find.descendant(
            of: find.widgetWithText(ListTile, 'b.png'),
            matching: find.byIcon(Icons.arrow_upward),
          ),
        )
        .dx;
    expect(downPos, lessThan(upPos), reason: '下移位于上移左侧');
  });

  testWidgets('追加图片:pickImages 结果合并进列表', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    pickPort.moreImages = ['/img/c.png'];
    await tester.tap(find.text('追加图片'));
    await tester.pumpAndSettle();

    expect(find.text('c.png'), findsOneWidget);
    expect(find.textContaining('共 3 张'), findsOneWidget);
  });

  testWidgets('删除全部图片 → 转换按钮禁用', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    for (final name in ['a.png', 'b.png']) {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, name),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
    }
    expect(find.text('尚未选择图片'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.ancestor(of: find.text('开始转换'), matching: find.byType(FilledButton)),
    );
    expect(btn.onPressed, isNull, reason: '空列表禁用转换');
  });

  testWidgets('完整流:开始转换 → Fake 收到 source → 完成弹窗', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    await tester.runAsync(() async {
      await tester.tap(find.text('开始转换'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleRealAsync(tester);

    expect(svc.convertImagesCalls, hasLength(1));
    expect(svc.receivedSources.single.paths, ['/img/a.png', '/img/b.png']);
    expect(find.byType(ExportCompleteDialog), findsOneWidget);
    expect(find.text('导出完成'), findsOneWidget);
  });
}

// ---- 测试替身 ----

class _FakeImagePickPort implements FilePickPort {
  List<String>? moreImages;

  @override
  Future<String?> pickMp4() async => null;

  @override
  Future<List<String>?> pickMp4s() async => null;

  @override
  Future<List<String>?> pickImages() async => moreImages;
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 1),
    width: 64,
    height: 64,
    fps: 15,
    codec: 'h264',
  );
}

class _ImgAdapter extends PlatformAdapter {
  _ImgAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/image_control_screen.dart';
import 'package:chameleon_gif/app/presentation/image_gif_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/features/export/presentation/export_complete_dialog.dart';
import 'package:chameleon_gif/features/export/presentation/param_dropdown_field.dart';
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

    // 默认 1 倍收起;展开菜单选 2 倍(缩放倍数经 <double?> 泛型定位,
    // 与帧率/速度的 <double> 区分,避免与速度行"1 倍"歧义)
    await tester.tap(find.byType(ParamDropdownField<double?>).first);
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

  testWidgets('精细化控制入口:每行齿轮存在,位于下移左侧;点击进入控制页', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 两行各有齿轮入口
    expect(find.byIcon(Icons.settings), findsNWidgets(2));
    // 齿轮位于下移按钮左侧(同 ListTile 内比较)
    final gearPos = tester
        .getCenter(
          find.descendant(
            of: find.widgetWithText(ListTile, 'a.png'),
            matching: find.byIcon(Icons.settings),
          ),
        )
        .dx;
    final downPos = tester
        .getCenter(
          find.descendant(
            of: find.widgetWithText(ListTile, 'a.png'),
            matching: find.byIcon(Icons.arrow_downward),
          ),
        )
        .dx;
    expect(gearPos, lessThan(downPos), reason: '齿轮位于下移左方');

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ImageControlScreen), findsOneWidget);
    expect(find.text('精细化控制 · 第 1 张'), findsOneWidget);
  });

  testWidgets('精细控制未操作:齿轮左侧不显示信息文本', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    expect(find.textContaining('缩放倍率'), findsNothing);
    expect(find.textContaining('宽度:'), findsNothing);
  });

  testWidgets('精细控制保存后:齿轮左侧显示参数信息,信息随图走', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 打开 a.png 控制页,选 2 倍 → 保存
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.settings),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 回到主页面:a.png 行齿轮左侧显示信息,b.png 行不显示
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.textContaining('缩放倍率:2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'b.png'),
        matching: find.textContaining('缩放倍率'),
      ),
      findsNothing,
    );

    // 下移 a.png → 信息随图走(第 2 行 a.png 仍带信息)
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.arrow_downward),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.textContaining('缩放倍率:2'),
      ),
      findsOneWidget,
      reason: '控制随图走:移动后 a.png 仍显示其参数',
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'b.png'),
        matching: find.textContaining('缩放倍率'),
      ),
      findsNothing,
    );

    // 删除 a.png → 信息消失
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'a.png'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    expect(find.textContaining('缩放倍率'), findsNothing);
  });

  testWidgets('窄屏布局:齿轮 + 4 按钮无溢出异常', (tester) async {
    final (app, router, _) = buildApp();
    tester.view.physicalSize = const Size(500, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await enterScreen(tester, router);

    expect(find.byIcon(Icons.settings), findsNWidgets(2));
    expect(tester.takeException(), isNull, reason: '窄布局不得 RenderFlex 溢出');
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

  testWidgets('BUG1 回归:完成弹窗打开后输入框失焦提交不叠加弹窗', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    await tester.runAsync(() async {
      await tester.tap(find.text('开始转换'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleRealAsync(tester);
    expect(find.byType(ExportCompleteDialog), findsOneWidget);

    // 模拟弹窗弹出瞬间输入框失焦(旧 bug:blur 提交写状态 → done 监听
    // 无守卫重进 showDialog → 叠加第二层弹窗,背景逐层变黑、需点多次
    // 关闭)
    final focusNode = tester
        .widget<TextField>(find.byType(TextField).first)
        .focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    focusNode.unfocus();
    await tester.pumpAndSettle();

    expect(
      find.byType(ExportCompleteDialog),
      findsOneWidget,
      reason: 'done 态失焦提交不得叠加弹窗(BUG1)',
    );
  });

  testWidgets('BUG1 回归:完成弹窗连点关闭不 double pop 页面', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    await tester.runAsync(() async {
      await tester.tap(find.text('开始转换'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleRealAsync(tester);
    expect(find.byType(ExportCompleteDialog), findsOneWidget);

    // 同帧连点关闭(旧 bug:onReset 未 await + pop 无条件,第二次 pop
    // 弹出页面路由回首页)
    await tester.tap(find.text('关闭'));
    await tester.tap(find.text('关闭'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
    expect(
      find.text('图片制作 GIF'),
      findsOneWidget,
      reason: '连点关闭不得 pop 页面(BUG1)',
    );
  });

  testWidgets('回归:每图时长输入 100 不回车,直接转换生效', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 每图时长框 = 第 1 个 TextField;输入 100 不按回车
    // (旧 bug:直接转换会用默认 1000ms,20 张图导出 20 秒)
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('开始转换'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleRealAsync(tester);

    expect(svc.convertImagesCalls, hasLength(1));
    expect(
      svc.lastSetting!.frameDurationMs,
      100,
      reason: '未回车输入也必须生效(不得回退默认 1000ms)',
    );
  });

  testWidgets('每图时长非法输入不回车 → 转换中止并提示', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();

    await tester.tap(find.text('开始转换'));
    await tester.pumpAndSettle();

    expect(svc.convertImagesCalls, isEmpty, reason: '非法输入不得启动转换');
    expect(find.text('每张图片停留时长须为数字(毫秒)'), findsOneWidget);
  });

  testWidgets('每图时长越界(99999)不回车 → 转换中止并提示,不得静默用旧值', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 旧 bug:越界值 updateFrameDurationMs 只设 formError,随后 updateLoop
    // 成功清错 → 转换静默用默认 1000ms
    await tester.enterText(find.byType(TextField).first, '99999');
    await tester.pump();

    await tester.tap(find.text('开始转换'));
    await tester.pumpAndSettle();

    expect(svc.convertImagesCalls, isEmpty, reason: '越界输入不得启动转换');
    expect(find.textContaining('每张图片停留时长需在'), findsOneWidget);
  });

  testWidgets('播放速度:选 2 倍 → 转换携带 playbackSpeed=2', (tester) async {
    final svc = FakeFfmpegService(writeOutput: false);
    final (app, router, _) = buildApp(service: svc);
    await pumpApp(tester, app);
    await enterScreen(tester, router);

    // 速度行默认 1 倍;展开菜单选 2 倍(速度 = 第 2 个 <double> 下拉,
    // 第 1 个是帧率;缩放倍数行同显示"1 倍"不影响泛型定位)
    await tester.tap(find.byType(ParamDropdownField<double>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('开始转换'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settleRealAsync(tester);

    expect(svc.convertImagesCalls, hasLength(1));
    expect(svc.lastSetting!.playbackSpeed, 2.0, reason: '2 倍速随任务传递');
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

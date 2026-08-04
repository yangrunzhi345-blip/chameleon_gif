import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/batch_failed_dialog.dart';
import 'package:chameleon_gif/app/presentation/batch_import_screen.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/features/task_queue/presentation/queue_page.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/fake_player_port.dart';

/// 批量完成弹窗全链路(宿主 + 失败弹窗 + 最终弹窗 + 四按钮导航)。
///
/// 注入带 [rootNavigatorKey] 的 router 使宿主弹窗生效;无会话的既有
/// 测试不受影响。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;
  late _FakeParseVideoPort parsePort;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_batch_flow_');
    parsePort = _FakeParseVideoPort();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  (Widget, GoRouter, InMemoryTaskRepository) buildApp({
    required FakeFfmpegService service,
    FilePickPort? pickPort,
  }) {
    final taskRepo = InMemoryTaskRepository();
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      routes: buildRoutes(),
    );
    final adapter = _TestAdapter(tempRoot.path);
    final app = ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(parsePort),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        if (pickPort != null) filePickPortProvider.overrideWithValue(pickPort),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(service),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: service,
            platformAdapter: adapter,
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: ChameleonGifApp(router: router),
    );
    return (app, router, taskRepo);
  }

  /// 大窗口(1280×800)下走双栏布局,表单所有控件(含底部开始按钮)直接可见。
  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> enterBatch(WidgetTester tester, GoRouter router) async {
    // fake async 中不能直接 await push(需 pump 推进导航),先启动再 settle
    unawaited(
      router.push(
        '/batch-import',
        extra: ['/tmp/a.mp4', '/tmp/b.mp4', '/tmp/c.mp4'],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 推进真实异步(任务执行/取消令牌路径)后再 settle 渲染弹窗。
  ///
  /// 交替 runAsync(真实事件循环:workDir 创建等 IO 完成)与 pump(flush
  /// fake zone 微任务队列,推进任务状态机到终态)后 settle 渲染。
  Future<void> settleRealAsync(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> startBatch(WidgetTester tester) async {
    await tester.tap(find.text('开始批量转换'));
    await tester.pump();
    // 任务执行含真实 IO(workDir 创建),fake async 不推进;runAsync 放行
    await settleRealAsync(tester);
  }

  testWidgets('全部成功 → 完成弹窗统计;返回首页后弹窗关闭', (tester) async {
    final (app, router, _) = buildApp(
      service: FakeFfmpegService(writeOutput: false),
    );
    await pumpApp(tester, app);
    await enterBatch(tester, router);
    await startBatch(tester);

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('所有的任务已经完成'), findsOneWidget);
    expect(find.textContaining('成功 3 个'), findsOneWidget);
    expect(find.textContaining('失败'), findsNothing, reason: '全成功无失败段');

    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('所有的任务已经完成'), findsNothing);
  });

  testWidgets('部分失败 → 失败弹窗列失败项;点"否" → 最终弹窗统计含失败', (tester) async {
    final (app, router, _) = buildApp(
      service: FakeFfmpegService(
        writeOutput: false,
        errorQueue: [const SourceBrokenException(errorCode: 'GIF_SRC_BROKEN')],
      ),
    );
    await pumpApp(tester, app);
    await enterBatch(tester, router);
    await startBatch(tester);

    // 失败询问弹窗:列出失败项(队列页同显失败任务,限定弹窗内查找)
    expect(find.text('部分任务失败'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BatchFailedDialog),
        matching: find.text('a.mp4'),
      ),
      findsOneWidget,
      reason: '失败项文件名',
    );

    await tester.tap(find.text('否'));
    await tester.pumpAndSettle();

    // 最终弹窗:统计含失败(取消任务不询问)
    expect(find.text('所有的任务已经完成'), findsOneWidget);
    expect(find.textContaining('成功 2 个'), findsOneWidget);
    expect(find.textContaining('失败 1 个'), findsOneWidget);

    await tester.tap(find.text('返回批量导入'));
    await tester.pumpAndSettle();
    // 恢复初始:空态批量页(表单重置,设置不动)
    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.text('已选 0 个文件'), findsOneWidget);
    expect(find.text('所有的任务已经完成'), findsNothing);
  });

  testWidgets('失败弹窗点"重新开始" → 仅重试失败项,重试成功后进最终弹窗', (tester) async {
    final service = FakeFfmpegService(
      writeOutput: false,
      errorQueue: [const SourceBrokenException(errorCode: 'GIF_SRC_BROKEN')],
    );
    final (app, router, _) = buildApp(service: service);
    await pumpApp(tester, app);
    await enterBatch(tester, router);
    await startBatch(tester);

    expect(find.text('部分任务失败'), findsOneWidget);
    await tester.tap(find.text('重新开始'));
    await tester.pump();
    await settleRealAsync(tester); // 重试任务执行(真实 IO)

    // 重试成功(错误队列已空)→ 最终弹窗全部成功;convert 共 4 次(3+1 重试)
    expect(find.text('所有的任务已经完成'), findsOneWidget);
    expect(find.textContaining('成功 3 个'), findsOneWidget);
    expect(service.convertCalls, hasLength(4), reason: '仅失败项重试执行一次');
  });

  testWidgets('最终弹窗"返回单独导入mp4" → 首页 + 自动文件选择 → 预览页', (tester) async {
    final pickPort = _FakeFilePickPort(singlePath: '/tmp/single.mp4');
    final (app, router, _) = buildApp(
      service: FakeFfmpegService(writeOutput: false),
      pickPort: pickPort,
    );
    await pumpApp(tester, app);
    await enterBatch(tester, router);
    await startBatch(tester);

    await tester.tap(find.text('返回单独导入mp4'));
    await tester.pumpAndSettle();

    // 回首页 + 自动触发文件选择 → 单文件预览页
    expect(find.byType(PreviewScreen), findsOneWidget);
  });

  testWidgets('全部取消 → 最终弹窗统计取消,预览按钮禁用', (tester) async {
    final service = FakeFfmpegService(
      writeOutput: false,
      blockNthConvert: [1, 2, 3],
    );
    final (app, router, taskRepo) = buildApp(service: service);
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    // 启动:任务阻塞执行中,队列页有 CircularProgressIndicator 无限动画,
    // 不能 pumpAndSettle,手动交替推进真实异步与帧
    await tester.tap(find.text('开始批量转换'));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.byType(QueuePage), findsOneWidget);

    // 全部取消:多轮交替推进(cancelAll 含真实 IO 清理,需多轮;第 12 轮
    // 令牌标记充分后放行阻塞 convert → 检测令牌 → 取消收尾),直到全部终态
    await tester.tap(find.byTooltip('全部取消'));
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() async {
        if (i == 12) service.unblockAll();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump(const Duration(milliseconds: 30));
      if ((await taskRepo.all()).every((t) => t.state.isFinal)) break;
    }
    // 任务全部终态 → 队列空态 + 弹窗,可 settle
    await tester.pumpAndSettle();

    expect(find.text('所有的任务已经完成'), findsOneWidget);
    expect(find.textContaining('取消 3 个'), findsOneWidget);
    final previewBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '预览'),
    );
    expect(previewBtn.onPressed, isNull, reason: '无成功输出,预览禁用');
  });
}

class _FakeFilePickPort implements FilePickPort {
  _FakeFilePickPort({this.singlePath});

  String? singlePath;

  @override
  Future<String?> pickMp4() async => singlePath;

  @override
  Future<List<String>?> pickMp4s() async => null;
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async {
    return VideoInfo(
      path: path,
      formatName: 'mp4',
      duration: const Duration(seconds: 10),
      width: 640,
      height: 360,
      fps: 30,
      codec: 'h264',
    );
  }
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

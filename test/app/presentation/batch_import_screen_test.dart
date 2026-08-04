import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/batch_import_screen.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
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

import '../../fixtures/fake_player_port.dart';

/// 批量导入设置页(P6-WP1.5):文件列表/移除/参数表单/入队跳转/回退。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;
  late _FakeParseVideoPort parsePort;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_batch_screen_');
    parsePort = _FakeParseVideoPort();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  (Widget, GoRouter, InMemoryTaskRepository) buildApp() {
    final taskRepo = InMemoryTaskRepository();
    final router = GoRouter(routes: buildRoutes());
    final adapter = _TestAdapter(tempRoot.path);
    final service = _BatchFakeService();
    final app = ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(parsePort),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
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

  /// 输入时间文本并触发 onSubmitted。
  Future<void> submitTime(
    WidgetTester tester,
    Finder field,
    String text,
  ) async {
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('进入设置页:3 个文件 + 参数表单 + 开始按钮可用', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);

    await enterBatch(tester, router);

    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('c.mp4'), findsOneWidget);
    expect(find.text('已选 3 个文件'), findsOneWidget);
    // 参数表单控件
    expect(find.text('帧率'), findsOneWidget);
    expect(find.text('宽度'), findsOneWidget);
    expect(find.text('循环'), findsOneWidget);
    expect(find.text('开始批量转换'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('移除单个文件 → 列表与计数更新', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    // 移除 b.mp4:该行 trailing IconButton(tooltip 移除)
    final removeButtons = find.byTooltip('移除');
    await tester.tap(removeButtons.at(1));
    await tester.pumpAndSettle();

    expect(find.text('b.mp4'), findsNothing);
    expect(find.text('已选 2 个文件'), findsOneWidget);
  });

  testWidgets('移除全部文件 → 开始按钮禁用', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    final removeButtons = find.byTooltip('移除');
    for (var i = 0; i < 3; i++) {
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();
    }

    expect(find.text('文件列表为空,请返回重新选择'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNull, reason: '空列表禁用开始');
  });

  testWidgets('点开始 → 3 任务入队并跳队列页', (tester) async {
    final (app, router, taskRepo) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    await tester.tap(find.text('开始批量转换'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    final tasks = await taskRepo.all();
    expect(tasks, hasLength(3), reason: '3 文件全部入队');
  });

  testWidgets('修改宽度为 480 px → 入队任务携带 width=480', (tester) async {
    final (app, router, taskRepo) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    await tester.tap(find.text('原图等比').first); // 宽度下拉(收起态 label)
    await tester.pumpAndSettle();
    await tester.tap(find.text('480 px').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始批量转换'));
    await tester.pumpAndSettle();

    final tasks = await taskRepo.all();
    expect(tasks, hasLength(3), reason: '3 文件全部入队');
    expect(tasks.first.settings.width, 480, reason: '下拉选择透传入队参数');
  });

  testWidgets('非法时间文本 → formError 红字 + 开始按钮禁用', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    await submitTime(
      tester,
      find.widgetWithText(TextField, '00:00.000'),
      'abc',
    );

    expect(find.text('开始时间格式非法(示例 00:03.200)'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNull, reason: 'formError 禁用开始');
  });

  testWidgets('extra 为 null → 回退返回,不显示设置页', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);

    unawaited(router.push('/batch-import'));
    await tester.pumpAndSettle();

    expect(find.byType(BatchImportScreen), findsNothing);
    expect(find.byType(HomePage), findsOneWidget, reason: '回退到主页');
  });
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

class _BatchFakeService implements FFmpegService {
  @override
  Future<ConvertResult> convert({
    required GifSetting setting,
    required VideoInfo video,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    await File(outputPath).writeAsBytes(List.filled(123, 1));
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }
}

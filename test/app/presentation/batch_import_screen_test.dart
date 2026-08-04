import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/batch_import_screen.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/app/presentation/settings_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
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

  (Widget, GoRouter, InMemoryTaskRepository) buildApp({
    FilePickPort? pickPort,
  }) {
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

  testWidgets('进入批量导入页:3 个文件 + 默认参数摘要 + 设置入口 + 开始按钮', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('c.mp4'), findsOneWidget);
    expect(find.text('已选 3 个文件'), findsOneWidget);
    // 默认参数摘要(只读)+ 设置入口(参数编辑控件已移除)
    expect(find.text('批量导入默认参数'), findsOneWidget);
    expect(find.textContaining('15 fps'), findsOneWidget, reason: '内置默认摘要');
    expect(find.widgetWithText(OutlinedButton, '批量导入设置'), findsOneWidget);
    expect(find.text('帧率'), findsNothing, reason: '参数编辑已移除,仅摘要');
    expect(find.text('开始批量转换'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('批量导入设置按钮 → 设置界面;返回 → 回到批量导入页', (tester) async {
    final (app, router, _) = buildApp();
    await pumpApp(tester, app);
    await enterBatch(tester, router);

    await tester.tap(find.widgetWithText(OutlinedButton, '批量导入设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // 返回:回到批量导入页(栈式导航,来源页即返回目标)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.text('已选 3 个文件'), findsOneWidget);
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

    expect(find.text('文件列表为空'), findsOneWidget);
    expect(find.text('文件列表为空,请点击"重新选择视频"添加文件'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重新选择视频'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNull, reason: '空列表禁用开始');
  });

  testWidgets('extra 空列表 → 停留空态(不回退),重新选择视频可填充', (tester) async {
    final pickPort = _FakeFilePickPort(
      pickMp4sResult: ['/tmp/x.mp4', '/tmp/y.mp4'],
    );
    final (app, router, _) = buildApp(pickPort: pickPort);
    await pumpApp(tester, app);

    unawaited(router.push('/batch-import', extra: const <String>[]));
    await tester.pumpAndSettle();

    // 停留空态:不回退、空提示 + 重新选择按钮 + 开始禁用
    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.text('已选 0 个文件'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '重新选择视频'), findsOneWidget);
    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNull, reason: '空列表禁用开始');

    // 点击重新选择 → 文件填充、开始启用(恢复初始后可继续导入)
    await tester.tap(find.widgetWithText(TextButton, '重新选择视频'));
    await tester.pumpAndSettle();
    expect(find.text('x.mp4'), findsOneWidget);
    expect(find.text('y.mp4'), findsOneWidget);
    expect(find.text('已选 2 个文件'), findsOneWidget);
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '开始批量转换'),
    );
    expect(button.onPressed, isNotNull, reason: '填充后启用开始');
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
    expect(tasks.first.settings.fps, 15.0, reason: '以默认参数入队');
    expect(tasks.first.settings.width, 0, reason: '默认原图等比');
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

class _FakeFilePickPort implements FilePickPort {
  _FakeFilePickPort({this.pickMp4sResult});

  List<String>? pickMp4sResult;

  @override
  Future<String?> pickMp4() async => null;

  @override
  Future<List<String>?> pickMp4s() async => pickMp4sResult;
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/batch_import_screen.dart';
import 'package:chameleon_gif/app/presentation/settings_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
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

/// 主页批量导入入口(P6-WP1.5):多选 → 设置页(无预览)→ 开始批量转换 → 队列页。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;
  late _FakeFilePickPort pickPort;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_batch_');
    pickPort = _FakeFilePickPort();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  /// 大窗口(1280×800)下设置页走双栏布局,"开始批量转换"直接可见。
  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(pickPort),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(_BatchFakeService()),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: _BatchFakeService(),
            platformAdapter: _TestAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
    );
  }

  testWidgets('批量导入 3 文件 → 先到设置页,点开始后入队并跳转队列页', (tester) async {
    pickPort.multiPaths = ['/tmp/a.mp4', '/tmp/b.mp4', '/tmp/c.mp4'];
    await pumpApp(tester, buildApp());

    await tester.tap(find.text('批量导入'));
    await tester.pumpAndSettle();

    // 设置页:文件列表 + 开始按钮(无预览)
    expect(find.byType(BatchImportScreen), findsOneWidget);
    expect(find.byType(QueuePage), findsNothing);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('c.mp4'), findsOneWidget);
    expect(find.text('开始批量转换'), findsOneWidget);

    await tester.tap(find.text('开始批量转换'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('c.mp4'), findsOneWidget);
  });

  testWidgets('首页批量导入设置按钮 → 直接进入设置界面', (tester) async {
    await pumpApp(tester, buildApp());

    await tester.tap(find.text('批量导入设置'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('批量导入默认参数'), findsOneWidget);

    // 返回 → 回首页(栈式导航,来源页即返回目标)
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('导入 MP4'), findsOneWidget);
  });

  testWidgets('设置页移除 1 文件后开始 → 2 任务入队', (tester) async {
    pickPort.multiPaths = ['/tmp/a.mp4', '/tmp/b.mp4', '/tmp/c.mp4'];
    await pumpApp(tester, buildApp());

    await tester.tap(find.text('批量导入'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('移除').at(1)); // 移除 b.mp4
    await tester.pumpAndSettle();
    expect(find.text('b.mp4'), findsNothing);

    await tester.tap(find.text('开始批量转换'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsNothing);
    expect(find.text('c.mp4'), findsOneWidget);
  });

  testWidgets('取消选择 → 无跳转无提示', (tester) async {
    pickPort.multiPaths = null;
    await pumpApp(tester, buildApp());

    await tester.tap(find.text('批量导入'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('全部解析失败 → 设置页点开始后 SnackBar 提示,不跳转', (tester) async {
    pickPort.multiPaths = ['/tmp/broken1.mp4', '/tmp/broken2.mp4'];
    await pumpApp(
      tester,
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appLoggerProvider.overrideWithValue(AppLogger()),
          filePickPortProvider.overrideWithValue(pickPort),
          parseVideoPortProvider.overrideWithValue(
            _FakeParseVideoPort(alwaysBroken: true),
          ),
          previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
          platformAdapterProvider.overrideWithValue(
            _TestAdapter(tempRoot.path),
          ),
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          historyRepositoryProvider.overrideWithValue(
            InMemoryHistoryRepository(),
          ),
          ffmpegServiceProvider.overrideWithValue(_BatchFakeService()),
          taskManagerProvider.overrideWith(
            (ref) => TaskManager(
              taskRepository: ref.read(taskRepositoryProvider),
              historyRepository: ref.read(historyRepositoryProvider),
              ffmpegService: _BatchFakeService(),
              platformAdapter: _TestAdapter(tempRoot.path),
              logger: AppLogger(),
              retryDelay: (_) async {},
            ),
          ),
        ],
        child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
      ),
    );

    await tester.tap(find.text('批量导入'));
    await tester.pumpAndSettle();
    expect(find.byType(BatchImportScreen), findsOneWidget);

    await tester.tap(find.text('开始批量转换'));
    await tester.pumpAndSettle();

    expect(find.byType(QueuePage), findsNothing);
    expect(find.text('批量导入失败,请检查文件'), findsOneWidget);
  });
}

class _FakeFilePickPort implements FilePickPort {
  List<String>? multiPaths;

  @override
  Future<String?> pickMp4() async => multiPaths?.firstOrNull;

  @override
  Future<List<String>?> pickMp4s() async => multiPaths;
}

class _FakeParseVideoPort implements ParseVideoPort {
  _FakeParseVideoPort({this.alwaysBroken = false});

  final bool alwaysBroken;

  @override
  Future<VideoInfo> parse(String path) async {
    if (alwaysBroken) {
      throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
    }
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

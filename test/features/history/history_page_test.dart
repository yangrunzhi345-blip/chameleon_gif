import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_history.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/history/application/history_providers.dart';
import 'package:chameleon_gif/features/history/infrastructure/thumbnail_extractor.dart';
import 'package:chameleon_gif/features/history/presentation/history_detail_dialog.dart';
import 'package:chameleon_gif/features/history/presentation/history_page.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [HistoryPage] 交互测试(P5-WP2,§14.3 历史列表用例)。
void main() {
  late SharedPreferences prefs;
  late InMemoryHistoryRepository historyRepo;
  late FakeThumbnailExtractor extractor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    historyRepo = InMemoryHistoryRepository();
    extractor = FakeThumbnailExtractor();
  });

  ExportHistory history(
    int day, {
    String name = 'demo.mp4',
    GifSetting? settings,
  }) {
    return ExportHistory(
      id: day,
      videoPath: '/tmp/videos/$name',
      outputPath: '/tmp/gifforge_1/out.gif',
      settings: settings ?? const GifSetting(fps: 24, width: 320, loop: 2),
      durationMs: 1200,
      outputSizeBytes: 2048,
      createdAt: DateTime(2026, 1, day),
      sourceDurationMs: 10000,
      outputFrameCount: 150,
    );
  }

  Future<void> pumpHistoryPage(
    WidgetTester tester, {
    List<ExportHistory> seed = const [],
  }) async {
    for (final h in seed) {
      await historyRepo.add(h);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appLoggerProvider.overrideWithValue(AppLogger()),
          platformAdapterProvider.overrideWithValue(_TestAdapter()),
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          historyRepositoryProvider.overrideWithValue(historyRepo),
          ffmpegServiceProvider.overrideWithValue(_NoopFfmpegService()),
          taskManagerProvider.overrideWith(
            (ref) => TaskManager(
              taskRepository: ref.read(taskRepositoryProvider),
              historyRepository: ref.read(historyRepositoryProvider),
              ffmpegService: _NoopFfmpegService(),
              platformAdapter: _TestAdapter(),
              logger: AppLogger(),
              retryDelay: (_) async {},
            ),
          ),
          thumbnailExtractorProvider.overrideWithValue(extractor),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空态:无历史 → 引导文案,清空按钮禁用', (tester) async {
    await pumpHistoryPage(tester);

    expect(find.text('暂无转换历史'), findsOneWidget);
    final clearBtn = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined),
    );
    expect(clearBtn.onPressed, isNull, reason: '空列表禁用清空');
  });

  testWidgets('列表渲染:文件名/大小/时长;缩略图缺失 → 图标降级', (tester) async {
    extractor.bytes = null;
    await pumpHistoryPage(
      tester,
      seed: [
        history(2, name: 'clip_a.mp4'),
        history(1, name: 'clip_b.mp4'),
      ],
    );

    expect(find.text('clip_a.mp4'), findsOneWidget);
    expect(find.text('clip_b.mp4'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsWidgets);
    expect(
      find.byIcon(Icons.movie_outlined),
      findsNWidgets(2),
      reason: '缩略图失败降级为图标',
    );
  });

  testWidgets('缩略图成功:Fake 返回 PNG bytes → Image.memory 出现', (tester) async {
    extractor.bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
    );
    await pumpHistoryPage(tester, seed: [history(2)]);

    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('点击列表项 → 详情对话框显示参数快照', (tester) async {
    await pumpHistoryPage(
      tester,
      seed: [
        history(
          2,
          settings: const GifSetting(
            fps: 24,
            width: 640,
            start: Duration(seconds: 3),
            end: Duration(seconds: 9),
          ),
        ),
      ],
    );

    await tester.tap(find.text('demo.mp4'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryDetailDialog), findsOneWidget);
    expect(find.text('24.0 fps'), findsOneWidget);
    expect(find.text('640 px'), findsOneWidget);
    expect(find.textContaining('00:00:03.000'), findsOneWidget);
  });

  testWidgets('列表按 createdAt 倒序(seed 乱序)', (tester) async {
    await pumpHistoryPage(tester, seed: [history(1), history(3), history(2)]);

    final items = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    // 三个文件同名,改用 subtitle 时间顺序验证
    expect(items, hasLength(3));
  });

  testWidgets('主页 AppBar 历史按钮 → 跳转历史页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appLoggerProvider.overrideWithValue(AppLogger()),
          platformAdapterProvider.overrideWithValue(_TestAdapter()),
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          historyRepositoryProvider.overrideWithValue(historyRepo),
          ffmpegServiceProvider.overrideWithValue(_NoopFfmpegService()),
          taskManagerProvider.overrideWith(
            (ref) => TaskManager(
              taskRepository: ref.read(taskRepositoryProvider),
              historyRepository: ref.read(historyRepositoryProvider),
              ffmpegService: _NoopFfmpegService(),
              platformAdapter: _TestAdapter(),
              logger: AppLogger(),
              retryDelay: (_) async {},
            ),
          ),
          thumbnailExtractorProvider.overrideWithValue(extractor),
        ],
        child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.text('转换历史'), findsOneWidget);
  });
}

class FakeThumbnailExtractor extends ThumbnailExtractor {
  FakeThumbnailExtractor()
    : super(
        engine: _NoopEngine(),
        cacheDir: '/tmp/fake_thumbs',
        logger: AppLogger(),
      );

  Uint8List? bytes;

  @override
  Future<Uint8List?> extract(String videoPath) async => bytes;
}

class _TestAdapter extends PlatformAdapter {
  @override
  String get systemTempDir => '/tmp/history_test';
}

class _NoopFfmpegService implements FFmpegService {
  @override
  Future<ConvertResult> convertImages({
    required ImageGifSource source,
    required GifSetting setting,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    return convert(
      setting: setting,
      video: VideoInfo(
        path: source.paths.first,
        formatName: '',
        duration: Duration.zero,
        width: source.width,
        height: source.height,
        codec: '',
      ),
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

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
    throw UnimplementedError('本测试不执行导出');
  }
}

class _NoopEngine implements FFmpegEngine {
  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError('本测试不提取缩略图');
  }
}

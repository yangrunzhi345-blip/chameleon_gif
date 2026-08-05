import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/features/timeline/application/timeline_providers.dart';
import 'package:chameleon_gif/features/timeline/presentation/timeline_bar.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';

/// [TimelineBar] 交互测试(参照 preview_controls_bar_test 拖动模式)。
void main() {
  late FakePlayerPort port;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget wrap({bool enabled = true}) {
    return ProviderScope(
      overrides: [
        previewPlayerPortProvider.overrideWithValue(port),
        // commitRange 联动导出表单,装配 export 链
        sharedPrefsProvider.overrideWithValue(prefs),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
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
      ],
      child: MaterialApp(
        home: Scaffold(body: TimelineBar(enabled: enabled)),
      ),
    );
  }

  Future<void> readyAndInit(WidgetTester tester) async {
    port = FakePlayerPort();
    await tester.pumpWidget(wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    container
        .read(timelineControllerProvider.notifier)
        .init(
          videoDuration: const Duration(seconds: 10),
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 8),
        );
    // 加载预览进入 ready(position/duration 流有数据)
    await container
        .read(previewControllerProvider.notifier)
        .load(
          const VideoInfo(
            path: '/tmp/videos/demo.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('渲染选区文本与快捷键提示', (tester) async {
    await readyAndInit(tester);

    expect(find.textContaining('00:02.0'), findsWidgets);
    expect(find.textContaining('I 设起点'), findsOneWidget);
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('拖动右句柄 → commitRange 更新选区并 seek', (tester) async {
    await readyAndInit(tester);

    final slider = find.byType(RangeSlider);
    // 从右 3/4 处向左拖(改 end)
    await tester.dragFrom(
      tester.getTopLeft(slider) +
          Offset(tester.getSize(slider).width * 0.75, 12),
      const Offset(-80, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    final sel = container.read(timelineControllerProvider);
    expect(sel.end, lessThan(const Duration(seconds: 8)), reason: 'end 被拖小');
    expect(port.seekCalls, isNotEmpty, reason: '拖动中节流 seek 已触发');
  });

  testWidgets('I/O 快捷键设起点/终点(当前播放位置)', (tester) async {
    await readyAndInit(tester);

    // 定位到 5s
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    port.emitPosition(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250)); // 位置流节流窗口

    // 聚焦时间轴后按 I
    await tester.tap(find.byType(TimelineBar));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(
      container.read(timelineControllerProvider).start,
      const Duration(seconds: 5),
    );
  });

  testWidgets('空格切换播放/暂停', (tester) async {
    await readyAndInit(tester);

    await tester.tap(find.byType(TimelineBar));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(port.pauseCount, 1, reason: '播放中按空格应暂停');
  });

  testWidgets('enabled=false 时 RangeSlider 禁用', (tester) async {
    port = FakePlayerPort();
    await tester.pumpWidget(wrap(enabled: false));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    container
        .read(timelineControllerProvider.notifier)
        .init(videoDuration: const Duration(seconds: 10));

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.onChanged, isNull);
  });
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

class _TestAdapter extends PlatformAdapter {
  @override
  String get systemTempDir => '/tmp/timeline_bar_test';
}

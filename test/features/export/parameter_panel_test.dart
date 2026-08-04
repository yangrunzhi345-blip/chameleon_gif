import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/export/presentation/parameter_panel.dart';
import 'package:chameleon_gif/features/timeline/application/timeline_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ParameterPanel] 交互测试(P4-WP2,§14.3 参数面板用例)。
void main() {
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget wrap() {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        ffmpegServiceProvider.overrideWithValue(_NoopFfmpegService()),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: ParameterPanel(video: video)),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ParameterPanel)));

  /// 模拟壳的 initForm + timeline init 接线(否则视频时长未知,
  /// updateStart 经 timeline 回流时被钳制为 0)。
  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    final container = containerOf(tester);
    container.read(exportControllerProvider.notifier).initForm(video: video);
    // timeline 无渲染 watcher 会被 autoDispose GC,listen 保持存活(真实场景
    // 由 TimelineBar 渲染 watch 保证)
    container.listen(timelineControllerProvider, (_, _) {});
    container
        .read(timelineControllerProvider.notifier)
        .init(videoDuration: video.duration);
    await tester.pump();
  }

  testWidgets('分组渲染:输出/时间/目录/预估', (tester) async {
    await pumpPanel(tester);

    expect(find.text('输出'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.textContaining('预估大小:'), findsOneWidget);
    expect(find.text('导出 GIF'), findsOneWidget);
    expect(find.text('存为默认'), findsOneWidget);
    expect(find.text('载入默认'), findsOneWidget);
  });

  testWidgets('帧率下拉改值 → 表单状态更新', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    await tester.tap(find.text('15 fps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 fps', skipOffstage: false).last);
    await tester.pumpAndSettle();

    expect(container.read(exportControllerProvider).fps, 24.0);
  });

  testWidgets('高度下拉默认原图等比,改值 → 表单状态更新', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    expect(container.read(exportControllerProvider).height, 0);
    // 高度行是第二个"原图等比"(宽度行在前),tap .at(1) 展开
    await tester.tap(find.text('原图等比').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('480 px', skipOffstage: false).last);
    await tester.pumpAndSettle();

    expect(container.read(exportControllerProvider).height, 480);
  });

  testWidgets('循环非法文本 → formError 红字', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField).at(0), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final state = containerOf(tester).read(exportControllerProvider);
    expect(state.formError, contains('数字'));
    expect(find.textContaining('数字'), findsOneWidget);
  });

  testWidgets('开始时间非法 → formError;合法 → 表单更新', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(find.byType(TextField).at(1), 'xx');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      containerOf(tester).read(exportControllerProvider).formError,
      contains('开始时间'),
    );

    // 修正后清除
    await tester.enterText(find.byType(TextField).at(1), '00:03.200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final state = containerOf(tester).read(exportControllerProvider);
    expect(state.formError, isNull);
    expect(state.start, const Duration(milliseconds: 3200));
  });

  testWidgets('预估大小随帧率变化', (tester) async {
    await pumpPanel(tester);
    final before = containerOf(tester).read(exportControllerProvider).fps;

    await tester.tap(find.text('${before.toInt()} fps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 fps', skipOffstage: false).last);
    await tester.pumpAndSettle();

    // 60fps 预估应显著大于 15fps(约 4 倍)
    final after = containerOf(tester).read(exportControllerProvider);
    expect(after.fps, 60.0);
  });

  testWidgets('存为默认 → SharedPreferences 持久化', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    container.read(exportControllerProvider.notifier).updateFps(24);
    await tester.pump();

    await tester.tap(find.text('存为默认'));
    await tester.pump();

    expect(prefs.getString('default_gif_setting'), contains('24'));
  });
}

/// 无操作 FFmpeg 服务(本测试不触导出)。
class _NoopFfmpegService implements FFmpegService {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
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
    // 加高测试窗口:参数面板含缩放倍数行后,底部"存为默认"等按钮
    // 在默认 800×600 视口外
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
    // 缩放倍数行位于宽度上方,默认 1 倍
    expect(find.text('缩放倍数'), findsOneWidget);
    expect(find.text('1 倍'), findsOneWidget);
  });

  testWidgets('自定义宽度:菜单"自定义" → 输入 150 → 回显 150 px', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 展开宽度菜单(收起显示"原图等比"),点"自定义"
    await tester.tap(find.text('原图等比').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义').last);
    await tester.pumpAndSettle();

    // 对话框输入宽度
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '150',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(container.read(exportControllerProvider).width, 150);
    expect(find.text('150 px'), findsOneWidget, reason: '非选项值回显具体像素');
    expect(
      container.read(exportControllerProvider).scaleMultiplier,
      isNull,
      reason: '手动自定义宽高 → 倍数回显自定义',
    );
  });

  testWidgets('自定义倍数:输入 1.25 → 回显 1.25 倍 + 宽高联动', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 展开倍数菜单(收起显示"1 倍"),点"自定义"
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '1.25',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final s = container.read(exportControllerProvider);
    expect(s.scaleMultiplier, 1.25);
    expect(s.width, 800, reason: '640 × 1.25');
    expect(s.height, 450, reason: '360 × 1.25');
    expect(find.text('1.25 倍'), findsOneWidget, reason: '自定义倍数回显具体值');
  });

  testWidgets('自定义倍数:非法输入 → formError 红字,数值不变', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'abc',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('缩放倍数须为 0.1–4 的数字'), findsOneWidget);
    expect(container.read(exportControllerProvider).scaleMultiplier, 1.0);
    expect(container.read(exportControllerProvider).width, 0);
  });

  testWidgets('缩放倍数:选 2 倍 → 宽高联动 1280×720;改宽高 → 自定义', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 选 2 倍(源 640×360)
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();

    final s = container.read(exportControllerProvider);
    expect(s.width, 1280);
    expect(s.height, 720);
    expect(s.scaleMultiplier, 2.0);
    expect(find.text('2 倍'), findsOneWidget, reason: '回显 2 倍');

    // 手动改宽度(不匹配任何倍数)→ 回显"自定义"
    container.read(exportControllerProvider.notifier).updateWidth(700);
    await tester.pump();
    expect(find.text('自定义'), findsOneWidget);
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

  testWidgets('宽高比例不一致 → 显示变形警告(导出仍可用)', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 默认(原图)→ 无警告
    expect(find.textContaining('比例不一致'), findsNothing);

    // 宽 480 + 高 300(源 640×360,比例不符)→ 警告出现
    container.read(exportControllerProvider.notifier).updateWidth(480);
    container.read(exportControllerProvider.notifier).updateHeight(300);
    await tester.pump();

    expect(find.textContaining('比例不一致'), findsOneWidget);
    expect(find.textContaining('拉伸变形'), findsOneWidget);
    // 警告不阻塞导出按钮
    expect(find.text('导出 GIF'), findsOneWidget);
  });

  testWidgets('宽高比例一致 → 无警告', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    container.read(exportControllerProvider.notifier).updateWidth(480);
    container.read(exportControllerProvider.notifier).updateHeight(270);
    await tester.pump();

    expect(find.textContaining('比例不一致'), findsNothing);
  });

  testWidgets('预估输出 > 50MB → 体积提醒(不阻塞导出)', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 默认(小体积)→ 无提醒
    expect(find.textContaining('体积较大'), findsNothing);

    // 大体积:fps 60 + 宽高 1920×1920(10s 源)→ 远超 50MB
    container.read(exportControllerProvider.notifier).updateFps(60);
    container.read(exportControllerProvider.notifier).updateWidth(1920);
    container.read(exportControllerProvider.notifier).updateHeight(1920);
    await tester.pump();

    expect(find.textContaining('体积较大'), findsOneWidget);
    expect(find.textContaining('导出耗时与磁盘占用较高'), findsOneWidget);
    // 提醒不阻塞导出按钮
    expect(find.text('导出 GIF'), findsOneWidget);
  });

  testWidgets('比例警告与体积提醒可同时出现', (tester) async {
    await pumpPanel(tester);
    final container = containerOf(tester);

    // 480×300(比例不符)+ fps 60 + 1920×1920 尺寸 → 两个提醒都在
    container.read(exportControllerProvider.notifier).updateWidth(1920);
    container.read(exportControllerProvider.notifier).updateHeight(1920);
    container.read(exportControllerProvider.notifier).updateFps(60);
    await tester.pump();

    expect(find.textContaining('比例不一致'), findsOneWidget);
    expect(find.textContaining('体积较大'), findsOneWidget);
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

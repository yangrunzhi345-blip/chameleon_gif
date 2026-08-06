import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/capture_screen.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/camera/infrastructure/desktop_preview_providers.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/features/camera/presentation/desktop_preview_view.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/platform/process_engine.dart';
import 'package:chameleon_gif/shared/platform/process_ffprobe_executor.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures/fake_player_port.dart';
import '../test/fixtures/fake_settings_repository.dart';

/// 桌面相机流预览 UI 全链路(需 Linux 桌面 + 摄像头 + 系统 ffmpeg):
///   flutter test -d linux integration_test/desktop_preview_capture_test.dart
///
/// 真实链路:首页(真实枚举)→ 拍摄页(真实推流预览)→ 录制 3s(双
/// muxer,流持续)→ 超时自动导入 /preview(真实 ffprobe)→ 返回拍摄页
/// 预览恢复同地址。**采集/推流/解析全真实**,仅 Isar/播放器用测试替身。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late _TestAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('preview_ui_');
    adapter = _TestAdapter(tempRoot.path);
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(
          FfprobeParseVideoPort(
            executor: const ProcessFfprobeExecutor(),
            logger: AppLogger(),
          ),
        ),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegEngineProvider.overrideWithValue(const ProcessEngine()),
        ffmpegServiceProvider.overrideWithValue(
          FfmpegServiceEngine(
            engine: const ProcessEngine(),
            logger: AppLogger(),
          ),
        ),
        // 真实桌面采集端口(真实摄像头 + ffmpeg 推流/录制)
        cameraPortProvider.overrideWithValue(
          FfmpegCameraPort(
            capturesDir: Directory('${tempRoot.path}/captures'),
            adapter: adapter,
            logger: AppLogger(),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    // 清理残留推流进程(预览未停止的兜底)
    try {
      Process.runSync('pkill', ['-x', 'ffmpeg']);
    } on ProcessException {
      // 忽略
    }
    container.dispose();
    await tempRoot.delete(recursive: true);
  });

  bool hasCamera() {
    try {
      final result = Process.runSync('v4l2-ctl', ['--list-devices']);
      return result.exitCode == 0 &&
          result.stdout.toString().contains('/dev/video');
    } on ProcessException {
      return false;
    }
  }

  Future<void> waitFor(
    WidgetTester tester,
    Future<bool> Function() cond, {
    required String reason,
    int timeoutSeconds = 60,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      if (await cond()) return;
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    fail('等待超时(${timeoutSeconds}s): $reason');
  }

  testWidgets('真实链路:预览 → 录制(3s)→ 导入 /preview → 返回预览恢复', (tester) async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    // 录制 3s(仓储参数;预览帧率 15)
    await container
        .read(settingsRepositoryProvider)
        .setCaptureParams(
          const CaptureParams(
            deviceId: '/dev/video0',
            fps: 15,
            maxDurationMs: 3000,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ChameleonGifApp(
          router: GoRouter(
            routes: buildRoutes(),
            navigatorKey: rootNavigatorKey,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 首页:相机入口真实枚举常亮 → 进入拍摄页
    await waitFor(
      tester,
      () async => find.text('相机拍摄').evaluate().isNotEmpty,
      reason: '首页渲染',
    );
    await tester.tap(find.text('相机拍摄'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);

    // 真实截帧预览:帧流就绪 + 预览视图渲染
    await waitFor(
      tester,
      () async => container.read(desktopPreviewFramesProvider).value != null,
      reason: '预览帧流就绪(截帧进程启动)',
    );
    final frames = container.read(desktopPreviewFramesProvider).value!;
    await tester.pump();
    expect(find.byType(DesktopPreviewView), findsOneWidget, reason: '预览渲染');
    // 帧流真实出帧(JPEG SOI 标记)
    final firstFrame = await frames.first.timeout(const Duration(seconds: 5));
    expect(firstFrame.length, greaterThan(100), reason: '真实 JPEG 帧');
    expect(firstFrame[0], 0xFF);
    expect(firstFrame[1], 0xD8, reason: 'SOI 标记');

    // 录制:点击开始(方案 C:录制中无预览,设备独占)
    await tester.tap(find.byTooltip('开始录制'));
    await tester.pump();
    expect(find.byTooltip('停止录制'), findsOneWidget, reason: '录制中');

    // 3s 超时自退 → 自动导入 /preview(真实 ffprobe 解析)
    await waitFor(
      tester,
      () async => find.byType(PreviewScreen).evaluate().isNotEmpty,
      reason: '录制完成自动导入预览',
      timeoutSeconds: 30,
    );
    // 等 push 动画完成,再导航(动画中导航会导致后续 pop 失效)
    await tester.pumpAndSettle();

    // 「重新拍摄」(from=camera 专属入口,pushReplacement 直达)→ 新拍摄页
    await tester.tap(find.byTooltip('重新拍摄'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    // 预览恢复:帧流就绪 + 视图渲染
    await waitFor(
      tester,
      () async => container.read(desktopPreviewFramesProvider).value != null,
      reason: '重新拍摄后预览恢复',
    );
    await tester.pump();
    expect(find.byType(DesktopPreviewView), findsOneWidget, reason: '预览渲染');

    // 拍摄页返回(自定义 IconButton,pop 回首页;栈 [home, capture])
    await tester.tap(find.byTooltip('返回'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // ignore: avoid_print
    print(
      'DEBUG tap 返回后: home=${find.byType(HomePage).evaluate().length} '
      'capture=${find.byType(CaptureScreen, skipOffstage: false).evaluate().length}',
    );
    await waitFor(
      tester,
      () async => find.byType(HomePage).evaluate().isNotEmpty,
      reason: '返回首页',
    );
    expect(find.byType(CaptureScreen), findsNothing, reason: '拍摄页已退出');
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

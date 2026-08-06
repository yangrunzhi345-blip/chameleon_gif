import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/capture_screen.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_preview_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/fake_player_port.dart';
import '../../fixtures/fake_settings_repository.dart';

/// [CaptureScreen] 测试:取景占位 / 录制编排 / 自动导入 / 错误语义。
///
/// 取景控制器 override 为 null(占位容器);编排经 FakeCameraPort 注入。
void main() {
  late Directory tempRoot;
  late FakeCameraPort cameraPort;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // mock SystemChrome 平台通道(录制锁定向;测试环境无真实通道,
    // 不 mock 则 await 挂起导致录制态不出现)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    tempRoot = await Directory.systemTemp.createTemp('capture_screen_');
    cameraPort = FakeCameraPort();
    final adapter = _TestAdapter(tempRoot.path);
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appLoggerProvider.overrideWithValue(AppLogger()),
        cameraPortProvider.overrideWithValue(cameraPort),
        cameraControllerProvider.overrideWith((ref) async => null),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(
          FakeFfmpegService(writeOutput: false),
        ),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: ref.read(ffmpegServiceProvider),
            platformAdapter: adapter,
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<void> pumpCapture(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ChameleonGifApp(
          router: GoRouter(
            routes: buildRoutes(),
            navigatorKey: rootNavigatorKey, // 自动导入 push 经此 key
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('相机拍摄'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
  }

  testWidgets('取景不可用(controller null)→ 占位文案', (tester) async {
    await pumpCapture(tester);
    expect(find.text('未检测到摄像头,请检查相机权限'), findsOneWidget);
    expect(find.byTooltip('开始录制'), findsOneWidget);
  });

  testWidgets('桌面盲拍(previewSupported=false)→ 盲拍占位,无重试', (tester) async {
    cameraPort.previewSupported = false;
    await pumpCapture(tester);
    expect(
      find.textContaining('桌面盲拍'),
      findsOneWidget,
      reason: '盲拍提示(无实时预览,录完回放确认)',
    );
    expect(find.text('重试'), findsNothing, reason: '盲拍恒静态,无重试');
    expect(find.byTooltip('开始录制'), findsOneWidget);
  });

  testWidgets('点录制 → FakeCameraPort 收到仓储参数 + 录制中态(停止钮+倒计时)', (tester) async {
    final completer = Completer<CaptureResult>();
    cameraPort.onCapture = (params, token) => completer.future;
    await pumpCapture(tester);

    await tester.tap(find.byTooltip('开始录制'));
    await tester.pump();

    expect(find.byTooltip('停止录制'), findsOneWidget, reason: '录制中显示停止钮');
    expect(find.textContaining(':'), findsWidgets, reason: '倒计时渲染');
    expect(cameraPort.captureCalls, hasLength(1));
    expect(cameraPort.captureCalls.single.fps, 15.0, reason: '仓储默认参数');

    completer.complete(
      const CaptureResult(
        finalPath: '/tmp/captures/capture_1.mp4',
        durationMs: 1000,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('录制完成 → 自动导入 → /preview', (tester) async {
    final completer = Completer<CaptureResult>();
    cameraPort.onCapture = (params, token) => completer.future;
    await pumpCapture(tester);

    await tester.tap(find.byTooltip('开始录制'));
    await tester.pump();
    completer.complete(
      const CaptureResult(
        finalPath: '/tmp/captures/capture_1.mp4',
        durationMs: 1000,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PreviewScreen), findsOneWidget, reason: '自动导入推预览');
    expect(find.byType(CaptureScreen), findsNothing);
  });

  testWidgets('CaptureException → SnackBar 中文文案,停留拍摄页', (tester) async {
    cameraPort.onCapture = (params, token) async =>
        throw const CaptureException(
          errorCode: 'GIF_CAPTURE_CAMERA_ERROR',
          userMessage: '相机不可用:测试错误',
        );
    await pumpCapture(tester);

    await tester.tap(find.byTooltip('开始录制'));
    await tester.pumpAndSettle();

    expect(find.text('相机不可用:测试错误'), findsOneWidget);
    expect(find.byType(CaptureScreen), findsOneWidget);
  });

  testWidgets('CaptureCancelledException → 静默(无 SnackBar)', (tester) async {
    cameraPort.onCapture = (params, token) async =>
        throw const CaptureCancelledException();
    await pumpCapture(tester);

    await tester.tap(find.byTooltip('开始录制'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CaptureScreen), findsOneWidget);
  });
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 5),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

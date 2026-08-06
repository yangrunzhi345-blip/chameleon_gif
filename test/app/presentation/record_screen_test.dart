import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/presentation/record_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/fake_player_port.dart';
import '../../fixtures/fake_screen_recorder_port.dart';
import '../../fixtures/fake_settings_repository.dart';

/// [RecordScreen] 测试:敏感提示 / 开始录制编排 / 自动导入 / 错误语义。
///
/// 编排经 FakeScreenRecorderPort 注入(record 挂 Completer 模拟原生
/// 挂起 Result);停止按钮经 FakeScreenRecorderPort.requestStop 触发。
void main() {
  late Directory tempRoot;
  late FakeScreenRecorderPort recorderPort;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('record_screen_');
    recorderPort = FakeScreenRecorderPort();
    final adapter = _TestAdapter(tempRoot.path);
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appLoggerProvider.overrideWithValue(AppLogger()),
        screenRecorderPortProvider.overrideWithValue(recorderPort),
        cameraPortProvider.overrideWithValue(FakeCameraPort()),
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
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<void> pumpRecord(WidgetTester tester) async {
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
    await tester.tap(find.text('屏幕录制'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsOneWidget);
  }

  testWidgets('启动即敏感内容确认横幅 + 开始按钮', (tester) async {
    await pumpRecord(tester);

    expect(find.textContaining('将录制整个屏幕'), findsOneWidget);
    expect(find.text('开始录制'), findsOneWidget);
  });

  testWidgets('开始录制 → FakeScreenRecorderPort 收到仓储参数(挂起中)', (tester) async {
    final completer = Completer<CaptureResult>();
    recorderPort.onRecord = (params, token) => completer.future;
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pump();

    expect(recorderPort.recordCalls, hasLength(1));
    expect(recorderPort.recordCalls.single.fps, 15.0, reason: '仓储默认参数');
    expect(recorderPort.recordCalls.single.maxDurationMs, 60000);

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
    recorderPort.onRecord = (params, token) => completer.future;
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pump();
    completer.complete(
      const CaptureResult(
        finalPath: '/tmp/captures/capture_1.mp4',
        durationMs: 1000,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PreviewScreen), findsOneWidget, reason: '自动导入推预览');
  });

  testWidgets('授权拒绝(CapturePermissionDeniedException)→ SnackBar 回 idle', (
    tester,
  ) async {
    recorderPort.onRecord = (params, token) async =>
        throw const CapturePermissionDeniedException(
          userMessage: '未获得录屏授权,已取消录制',
        );
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pumpAndSettle();

    expect(find.text('未获得录屏授权,已取消录制'), findsOneWidget);
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(find.text('开始录制'), findsOneWidget, reason: '回 idle 可重新发起');
  });

  testWidgets('取消(CaptureCancelledException)→ 静默', (tester) async {
    recorderPort.onRecord = (params, token) async =>
        throw const CaptureCancelledException();
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
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

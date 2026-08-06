import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chameleon_gif/app/application/capture_import_use_case.dart';
import 'package:chameleon_gif/app/application/capture_session_controller.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/app/application/providers.dart';

import '../../fixtures/fake_camera_port.dart';

/// [CaptureSessionController] 单测:状态机/方向记录/异常映射/计时/停止。
void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer build({FakeCameraPort? camera}) {
    return ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        cameraPortProvider.overrideWithValue(camera ?? FakeCameraPort()),
        // 自动导入 no-op(真实实现经 rootNavigatorKey 导航,需 WidgetsBinding)
        captureImportUseCaseProvider.overrideWithValue(
          _FakeCaptureImportUseCase(),
        ),
      ],
    )..listen(captureSessionControllerProvider, (_, _) {});
  }

  CaptureSessionState state() =>
      container.read(captureSessionControllerProvider);

  tearDown(() => container.dispose());

  test('start:拍摄成功 → 方向记录 + 参数透传 + 自动导入后回 ready', () async {
    final camera = FakeCameraPort();
    container = build(camera: camera);
    final notifier = container.read(captureSessionControllerProvider.notifier);

    await notifier.start(portrait: false); // 横屏拍摄

    expect(camera.setDevicePortraitCalls, [false], reason: '方向经接口记录');
    expect(camera.captureCalls, hasLength(1));
    expect(camera.captureCalls.single.fps, 15.0);
    expect(state().phase, CapturePhase.ready);
    expect(state().errorMessage, isNull);
    expect(state().elapsed, Duration.zero);
  });

  test('start:拍摄异常 → errorMessage 文案 + 回 ready;消费后清空', () async {
    final camera = FakeCameraPort(
      error: const CaptureException(
        errorCode: 'GIF_CAP_FAILED',
        userMessage: '拍摄失败,请重试',
      ),
    );
    container = build(camera: camera);
    final notifier = container.read(captureSessionControllerProvider.notifier);

    await notifier.start(portrait: true);

    expect(state().errorMessage, '拍摄失败,请重试');
    expect(state().phase, CapturePhase.ready);
    notifier.clearError();
    expect(state().errorMessage, isNull);
  });

  test('start:取消(CaptureCancelledException)→ 静默无错误', () async {
    final camera = FakeCameraPort(error: const CaptureCancelledException());
    container = build(camera: camera);
    final notifier = container.read(captureSessionControllerProvider.notifier);

    await notifier.start(portrait: true);

    expect(state().errorMessage, isNull, reason: '取消静默');
    expect(state().phase, CapturePhase.ready);
  });

  test('计时:拍摄中 500ms ticker 累加 elapsed', () async {
    final completer = Completer<CaptureResult>();
    final camera = FakeCameraPort(
      onCapture: (params, token) => completer.future,
    );
    container = build(camera: camera);
    final notifier = container.read(captureSessionControllerProvider.notifier);
    final future = notifier.start(portrait: true); // 拍摄挂起,不 await

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(state().phase, CapturePhase.recording);
    expect(state().elapsed, const Duration(seconds: 1));

    completer.complete(
      const CaptureResult(finalPath: '/tmp/cap.mp4', durationMs: 1000),
    );
    await future;
    expect(state().phase, CapturePhase.ready);
    expect(state().elapsed, Duration.zero, reason: '结束清零');
  });

  test('stop:finishing 态 + requestStop 调用', () async {
    final camera = FakeCameraPort();
    container = build(camera: camera);
    final notifier = container.read(captureSessionControllerProvider.notifier);

    final future = notifier.stop();

    expect(state().phase, CapturePhase.finishing);
    await future;
    expect(camera.requestStopCalls, hasLength(1));
  });
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 1),
    width: 64,
    height: 64,
    fps: 15,
    codec: 'h264',
  );
}

/// 自动导入替身(记录调用,不做导航)。
class _FakeCaptureImportUseCase extends CaptureImportUseCase {
  _FakeCaptureImportUseCase()
    : super(
        importVideoUseCase: _FakeImportVideoUseCase(),
        onImported: (_, _) async {},
        logger: AppLogger(),
      );

  @override
  Future<VideoInfo> execute(String path, {CaptureSource? source}) async =>
      _FakeParseVideoPort().parse(path);
}

class _FakeImportVideoUseCase extends ImportVideoUseCase {
  _FakeImportVideoUseCase()
    : super(parseVideoPort: _FakeParseVideoPort(), logger: AppLogger());
}

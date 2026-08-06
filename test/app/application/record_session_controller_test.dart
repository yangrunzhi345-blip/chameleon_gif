import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chameleon_gif/app/application/capture_import_use_case.dart';
import 'package:chameleon_gif/app/application/record_session_controller.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';
import 'package:chameleon_gif/features/screen_record/application/region_picker.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/app/application/providers.dart';

import '../../fixtures/fake_screen_recorder_port.dart';

/// [RecordSessionController] 单测:状态机/异常映射/计时/归零写库/框选。
void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer build({
    FakeScreenRecorderPort? recorder,
    _FakeRegionPicker? picker,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        screenRecorderPortProvider.overrideWithValue(
          recorder ?? FakeScreenRecorderPort(),
        ),
        screenRegionPickerProvider.overrideWithValue(
          picker ?? _FakeRegionPicker(),
        ),
        // 自动导入 no-op(真实实现经 rootNavigatorKey 导航,需 WidgetsBinding)
        captureImportUseCaseProvider.overrideWithValue(
          _FakeCaptureImportUseCase(),
        ),
      ],
    )..listen(recordSessionControllerProvider, (_, _) {});
  }

  RecordSessionState state() => container.read(recordSessionControllerProvider);

  tearDown(() => container.dispose());

  test('init:带旧区域 → 归零写库(2026-08-07 需求)', () async {
    container = build();
    // 预置旧区域(直接操作仓储)
    await container
        .read(settingsRepositoryProvider)
        .setRecordParams(
          const RecordParams(
            fps: 24,
            regionX: 100,
            regionY: 200,
            regionWidth: 300,
            regionHeight: 400,
          ),
        );
    container.read(recordSessionControllerProvider.notifier).init();

    final saved = container.read(settingsRepositoryProvider).recordParams!;
    expect(saved.regionX, isNull, reason: '旧区域清空');
    expect(saved.regionY, isNull);
    expect(saved.regionWidth, isNull);
    expect(saved.regionHeight, isNull);
    expect(saved.fps, 24, reason: '非区域字段保留');
    expect(state().recordParams!.regionX, isNull);
  });

  test('init:无旧区域 → 原样载入', () async {
    container = build();
    container.read(recordSessionControllerProvider.notifier).init();

    expect(state().recordParams, isNotNull);
    expect(state().recordParams!.regionX, isNull);
  });

  test('start:录制成功 → 参数透传 + 自动导入后回 idle', () async {
    final recorder = FakeScreenRecorderPort(
      onRecord: (params, token) async =>
          const CaptureResult(finalPath: '/tmp/rec.mp4', durationMs: 1000),
    );
    container = build(recorder: recorder);
    final notifier = container.read(recordSessionControllerProvider.notifier);
    notifier.init();

    await notifier.start();

    expect(recorder.recordCalls, hasLength(1));
    expect(recorder.recordCalls.single.fps, 15.0);
    expect(state().phase, RecordPhase.idle);
    expect(state().errorMessage, isNull);
    expect(state().elapsed, Duration.zero);
  });

  test('start:授权拒绝(CaptureException)→ errorMessage 文案 + 回 idle', () async {
    final recorder = FakeScreenRecorderPort(
      error: const CaptureException(
        errorCode: 'GIF_CAP_PERMISSION',
        userMessage: '录制权限被拒绝,请在系统设置中允许',
      ),
    );
    container = build(recorder: recorder);
    final notifier = container.read(recordSessionControllerProvider.notifier);

    await notifier.start();

    expect(state().errorMessage, isNotNull, reason: '一次性错误文案');
    expect(state().phase, RecordPhase.idle);
    notifier.clearError();
    expect(state().errorMessage, isNull, reason: '消费后清空');
  });

  test('start:取消(CaptureCancelledException)→ 静默无错误', () async {
    final recorder = FakeScreenRecorderPort(
      error: const CaptureCancelledException(),
    );
    container = build(recorder: recorder);
    final notifier = container.read(recordSessionControllerProvider.notifier);

    await notifier.start();

    expect(state().errorMessage, isNull, reason: '取消静默');
    expect(state().phase, RecordPhase.idle);
  });

  test('计时:录制中 500ms ticker 累加 elapsed', () async {
    final completer = Completer<CaptureResult>();
    final recorder = FakeScreenRecorderPort(
      onRecord: (params, token) => completer.future,
    );
    container = build(recorder: recorder);
    final notifier = container.read(recordSessionControllerProvider.notifier);
    final future = notifier.start(); // 录制挂起,不 await

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(state().phase, RecordPhase.recording);
    expect(state().elapsed, const Duration(seconds: 1));

    completer.complete(
      const CaptureResult(finalPath: '/tmp/rec.mp4', durationMs: 1000),
    );
    await future;
    expect(state().phase, RecordPhase.idle);
    expect(state().elapsed, Duration.zero, reason: '结束清零');
  });

  test('stop:finishing 态 + requestStop 调用', () async {
    final recorder = FakeScreenRecorderPort();
    container = build(recorder: recorder);
    final notifier = container.read(recordSessionControllerProvider.notifier);

    final future = notifier.stop();

    expect(state().phase, RecordPhase.finishing);
    await future;
    expect(recorder.requestStopCalls, hasLength(1));
  });

  test('pickRegion:框选成功 → 区域回填 + 写库;取消 → 不变', () async {
    final picker = _FakeRegionPicker(
      result: const RegionGeometry(x: 10, y: 20, width: 300, height: 200),
    );
    container = build(picker: picker);
    final notifier = container.read(recordSessionControllerProvider.notifier);
    notifier.init();

    final next = await notifier.pickRegion();

    expect(next!.regionX, 10);
    expect(next.regionY, 20);
    expect(next.regionWidth, 300);
    expect(next.regionHeight, 200);
    final saved = container.read(settingsRepositoryProvider).recordParams!;
    expect(saved.regionX, 10, reason: '持久化同步');

    picker.result = null; // 取消
    expect(await notifier.pickRegion(), isNull);
    expect(
      container.read(settingsRepositoryProvider).recordParams!.regionX,
      10,
    );
  });
}

class _FakeRegionPicker implements RegionPicker {
  _FakeRegionPicker({this.result});

  RegionGeometry? result;

  @override
  bool get isAvailable => true;

  @override
  Future<RegionGeometry?> pick() async => result;
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

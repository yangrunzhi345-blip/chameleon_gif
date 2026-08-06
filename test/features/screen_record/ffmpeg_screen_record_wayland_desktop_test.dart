import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/ffmpeg_screen_recorder.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面录屏 **Wayland 本机真实实测**(wf-recorder + wlr-screencopy)。
///
/// 依赖:Wayland 会话(如 niri)+ wf-recorder 已装。验证:能力探测 →
/// 真实录制(requestStop SIGTERM 封口)→ 产物 mp4 可解析 → 取消清理。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('record_wayland_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  bool isWayland() =>
      Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() == 'wayland';

  test('本机实测:能力探测 → 真实录制(requestStop)→ 产物可解析', () async {
    if (!isWayland()) {
      markTestSkipped('非 Wayland 会话');
      return;
    }
    final recorder = FfmpegScreenRecorder(
      capturesDir: capturesDir,
      tempDir: Directory('${tempRoot.path}/tmp'),
      adapter: PlatformAdapter(),
      logger: AppLogger(),
    );
    // 1. 能力探测:wfRecorder + 可用(入口常亮)
    final caps = await recorder.queryCapabilities();
    expect(caps.captureMethod, RecordCaptureMethod.wfRecorder);
    expect(caps.screenCaptureAvailable, isTrue, reason: 'wf-recorder 已装');
    expect(caps.supportsRegions, isTrue);

    // 2. 真实录制 2s(requestStop SIGTERM 封口)
    final future = recorder.record(
      params: const RecordParams(fps: 15, maxDurationMs: 30000),
      cancelToken: null,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await recorder.requestStop();
    final result = await future;
    expect(File(result.finalPath).existsSync(), isTrue, reason: '产物落位');
    final probe = Process.runSync('ffprobe', [
      '-v',
      'error',
      '-show_format',
      result.finalPath,
    ]);
    expect(probe.exitCode, 0, reason: '产物可解析');
    final duration = RegExp(
      r'duration=([\d.]+)',
    ).firstMatch(probe.stdout.toString());
    expect(duration, isNotNull, reason: '含时长元数据');
    expect(
      double.parse(duration!.group(1)!),
      greaterThanOrEqualTo(1.0),
      reason: '实际录制时长',
    );

    // 3. 取消:清理无残留
    final token = CancelToken();
    final future2 = recorder.record(
      params: const RecordParams(fps: 15, maxDurationMs: 30000),
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    token.cancel();
    await expectLater(future2, throwsA(isA<CaptureCancelledException>()));
    expect(
      capturesDir.existsSync() ? capturesDir.listSync() : const [],
      isEmpty,
      reason: '取消不落位',
    );
  });
}

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
    final tmpDir = Directory('${tempRoot.path}/tmp')
      ..createSync(recursive: true);
    final recorder = FfmpegScreenRecorder(
      capturesDir: capturesDir,
      tempDir: tmpDir,
      adapter: PlatformAdapter(),
      logger: AppLogger(),
    );
    // 1. 能力探测:wfRecorder + 可用(入口常亮)
    final caps = await recorder.queryCapabilities();
    expect(caps.captureMethod, RecordCaptureMethod.wfRecorder);
    expect(caps.screenCaptureAvailable, isTrue, reason: 'wf-recorder 已装');
    expect(caps.supportsRegions, isTrue);

    // 2. 真实录制 2s(requestStop SIGTERM 封口)。wf-recorder 首帧
    // 启动耗时受桌面负载影响(实测偶发 2s+),固定延时会导致产物
    // 时长偏短的 flaky;产物时长不足 1s 时重录一次(不弱化实测语义)。
    var finalPath = '';
    var recordedDuration = 0.0;
    ProcessResult? probe;
    for (var attempt = 0; attempt < 2; attempt++) {
      final future = recorder.record(
        params: const RecordParams(fps: 15, maxDurationMs: 30000),
        cancelToken: null,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await recorder.requestStop();
      final result = await future;
      finalPath = result.finalPath;
      expect(File(finalPath).existsSync(), isTrue, reason: '产物落位');
      probe = Process.runSync('ffprobe', [
        '-v',
        'error',
        '-show_format',
        finalPath,
      ]);
      expect(probe.exitCode, 0, reason: '产物可解析');
      final duration = RegExp(
        r'duration=([\d.]+)',
      ).firstMatch(probe.stdout.toString());
      expect(duration, isNotNull, reason: '含时长元数据');
      recordedDuration = double.parse(duration!.group(1)!);
      if (recordedDuration >= 1.0) break;
    }
    expect(recordedDuration, greaterThanOrEqualTo(1.0), reason: '实际录制时长');

    // 3. 取消:无新产物(目录内容数与录制后一致,不含本次取消的半成品)
    final filesAfterRecord = capturesDir.existsSync()
        ? capturesDir.listSync().length
        : 0;
    final token = CancelToken();
    final future2 = recorder.record(
      params: const RecordParams(fps: 15, maxDurationMs: 30000),
      cancelToken: token,
    );
    await Future<void>.delayed(const Duration(milliseconds: 800));
    token.cancel();
    await expectLater(future2, throwsA(isA<CaptureCancelledException>()));
    expect(
      capturesDir.existsSync() ? capturesDir.listSync().length : 0,
      filesAfterRecord,
      reason: '取消不产生新产物',
    );
  });
}

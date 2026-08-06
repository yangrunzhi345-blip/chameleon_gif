import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面相机拍摄**本机真实实测**(真实 ffmpeg + 真实摄像头;无设备跳过)。
///
/// WP5 阶段门:超时自退落位 / 取消清理 / 产物 ffprobe 可解析。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('cam_real_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
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

  FfmpegCameraPort buildPort() => FfmpegCameraPort(
    capturesDir: capturesDir,
    adapter: PlatformAdapter(),
    logger: AppLogger(),
  );

  test('本机实测:超时自退(-t 2s)→ 落位,ffprobe 可解析,时长约 2s', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    final result = await port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        maxDurationMs: 2000,
        fps: 15,
      ),
      cancelToken: null,
    );
    expect(File(result.finalPath).existsSync(), isTrue, reason: '产物落位');
    expect(result.durationMs, inInclusiveRange(1500, 5000), reason: '-t 到时自退');

    final probe = Process.runSync('ffprobe', [
      '-v',
      'error',
      '-show_format',
      result.finalPath,
    ]);
    expect(probe.exitCode, 0, reason: 'ffprobe 可解析产物');
    final duration = RegExp(
      r'duration=([\d.]+)',
    ).firstMatch(probe.stdout.toString());
    expect(duration, isNotNull, reason: '含时长元数据');
    final seconds = double.parse(duration!.group(1)!);
    expect(seconds, inInclusiveRange(1.5, 4.0), reason: '实际时长约 2s');
  });

  test('本机实测:录制中取消 → 半成品清理,素材目录无残留', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    final token = CancelToken();
    final future = port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        maxDurationMs: 30000,
        fps: 15,
      ),
      cancelToken: token,
    );
    // 等待进程启动(会话就绪),再取消
    await Future<void>.delayed(const Duration(milliseconds: 800));
    token.cancel();
    await expectLater(future, throwsA(isA<CaptureCancelledException>()));
    expect(
      capturesDir.existsSync() ? capturesDir.listSync() : const [],
      isEmpty,
      reason: '取消不落位',
    );
  });
}

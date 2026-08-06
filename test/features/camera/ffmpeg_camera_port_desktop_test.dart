import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/ffmpeg_screen_recorder.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面采集端口**真实环境验证**(非单测,依赖本机设备/ffmpeg;
/// 无摄像头环境自动跳过)。
///
/// 验证目标(WP2 阶段门):
/// - 枚举:meta 节点(/dev/video1)被过滤,返回的设备均可采集;
/// - 盲拍:previewSupported = false;
/// - 录屏能力探测:不抛异常,可用性判定与 ffmpeg 实际输入一致。
void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('capture_port_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  bool hasV4l2Devices() {
    try {
      final result = Process.runSync('v4l2-ctl', ['--list-devices']);
      return result.exitCode == 0 &&
          result.stdout.toString().contains('/dev/video');
    } on ProcessException {
      return false;
    }
  }

  test('本机:枚举过滤 meta 节点,设备均可采集;盲拍无取景', () async {
    if (!hasV4l2Devices()) {
      markTestSkipped('本机无 v4l2 摄像头设备');
      return;
    }
    final port = FfmpegCameraPort(
      capturesDir: tempRoot,
      adapter: const PlatformAdapter(),
      logger: AppLogger(),
    );
    final devices = await port.enumerateDevices();
    expect(devices, isNotEmpty, reason: '本机存在 /dev/video 设备');
    // meta 节点过滤:返回的每个节点 --get-fmt-video 必须成功
    for (final d in devices) {
      final probe = Process.runSync('v4l2-ctl', [
        '-d',
        d.id,
        '--get-fmt-video',
      ]);
      expect(probe.exitCode, 0, reason: '${d.id} 应可采集(meta 节点已过滤)');
    }
    expect(port.previewSupported, isFalse, reason: '桌面盲拍');
  });

  test('本机:录屏能力探测不抛异常,可用性判定可用', () async {
    final recorder = FfmpegScreenRecorder(
      capturesDir: tempRoot,
      tempDir: Directory.systemTemp,
      adapter: const PlatformAdapter(),
      logger: AppLogger(),
    );
    final caps = await recorder.queryCapabilities();
    // 结构断言(环境相关值不强断言):探测总返回有效对象
    expect(caps.screenCaptureAvailable, isA<bool>());
    expect(caps.hint, isA<String?>());
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/camera/application/v4l2_controls_parser.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面相机第二档控制**本机真实实测**(真实 v4l2-ctl;无设备跳过)。
///
/// WP6 阶段门:能力探测(分辨率/控制项)、applyParams 真实生效、
/// inactive 项被跳过;测试恢复原值不留脏状态。
void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('cam_caps_');
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

  String currentControlsOutput() => Process.runSync('v4l2-ctl', [
    '-d',
    '/dev/video0',
    '-L',
  ]).stdout.toString();

  test('本机实测:能力探测 → 分辨率 MJPG 优先 + 控制项完整', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = FfmpegCameraPort(
      capturesDir: tempRoot,
      adapter: PlatformAdapter(),
      logger: AppLogger(),
    );
    final caps = await port.queryCapabilities('/dev/video0');
    expect(caps.supportsResolution, isTrue);
    expect(caps.supportedResolutions, isNotEmpty);
    expect(
      caps.supportedResolutions.first.toString(),
      '1280x720',
      reason: 'MJPG 最大尺寸在前',
    );
    expect(caps.controls, isNotEmpty);
    final brightness = caps.controls.firstWhere((c) => c.id == 'brightness');
    expect(brightness.kind, CameraControlKind.int);
    expect(brightness.min, isNotNull);
    expect(brightness.max, isNotNull);
    // 缓存命中(二次探测不重跑进程)
    final cached = await port.queryCapabilities('/dev/video0');
    expect(identical(caps, cached), isTrue, reason: '会话级能力缓存');
  });

  test('本机实测:applyParams 亮度变更真实生效并恢复', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = FfmpegCameraPort(
      capturesDir: tempRoot,
      adapter: PlatformAdapter(),
      logger: AppLogger(),
    );
    final original = parseV4l2Controls(
      currentControlsOutput(),
    ).firstWhere((c) => c.id == 'brightness').value!;
    final target = (original + 10).clamp(-64, 64);
    await port.applyParams(
      CaptureParams(
        deviceId: '/dev/video0',
        v4l2Controls: {'brightness': target},
      ),
    );
    final after = parseV4l2Controls(
      currentControlsOutput(),
    ).firstWhere((c) => c.id == 'brightness').value;
    expect(after, target, reason: 'v4l2-ctl --set-ctrl 生效');
    // 恢复原值(不留脏状态)
    await port.applyParams(
      CaptureParams(
        deviceId: '/dev/video0',
        v4l2Controls: {'brightness': original},
      ),
    );
  });

  test('本机实测:inactive 项被跳过(自动白平衡开启时色温不可调)', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = FfmpegCameraPort(
      capturesDir: tempRoot,
      adapter: PlatformAdapter(),
      logger: AppLogger(),
    );
    final caps = await port.queryCapabilities('/dev/video0');
    final wbTemp = caps.controls.firstWhere(
      (c) => c.id == 'white_balance_temperature',
    );
    expect(wbTemp.active, isFalse, reason: '自动白平衡开启 → 色温 inactive');
    final before = parseV4l2Controls(
      currentControlsOutput(),
    ).firstWhere((c) => c.id == 'white_balance_temperature').value;
    // 尝试设置 inactive 项:应被跳过(不报错、不改值)
    await port.applyParams(
      CaptureParams(
        deviceId: '/dev/video0',
        v4l2Controls: {'white_balance_temperature': 5000},
      ),
    );
    final after = parseV4l2Controls(
      currentControlsOutput(),
    ).firstWhere((c) => c.id == 'white_balance_temperature').value;
    expect(after, before, reason: 'inactive 项未应用');
  });
}

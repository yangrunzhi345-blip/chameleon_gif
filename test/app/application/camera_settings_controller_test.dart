import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/camera_settings_controller.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_settings_repository.dart';

/// 相机设置控制器:桌面路径适配(FakeCameraPort 非 CameraPortImpl →
/// 接口方法走通;设备切换/白平衡联动重探)。
void main() {
  late ProviderContainer container;
  late FakeCameraPort port;

  const brightness = CameraControlCapability(
    id: 'brightness',
    kind: CameraControlKind.int,
    min: -64,
    max: 64,
    step: 1,
    value: 0,
  );
  const wbAuto = CameraControlCapability(
    id: 'white_balance_automatic',
    kind: CameraControlKind.bool,
    value: 1,
  );

  setUp(() {
    port = FakeCameraPort(
      devices: const [
        CameraDevice(id: '/dev/video0', name: 'WebCam (/dev/video0)'),
      ],
      capabilities: const CameraCapabilities(
        supportsResolution: true,
        supportedResolutions: [CaptureResolution(width: 1280, height: 720)],
        controls: [brightness, wbAuto],
      ),
    );
    container = ProviderContainer(
      overrides: [
        cameraPortProvider.overrideWithValue(port),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('probe():接口路径枚举 + 能力探测(Fake 非 CameraPortImpl 同样走通)', () async {
    final controller = container.read(
      cameraSettingsControllerProvider.notifier,
    );
    await controller.probe();
    final state = container.read(cameraSettingsControllerProvider);
    expect(state.devices, hasLength(1));
    expect(state.deviceId, '/dev/video0');
    expect(state.capabilities?.controls, [brightness, wbAuto]);
    expect(port.enumerateDevicesCalls, hasLength(1));
  });

  test('updateDeviceId:桌面分支 applyParams + 重探能力', () async {
    final controller = container.read(
      cameraSettingsControllerProvider.notifier,
    );
    await controller.probe();
    final probesBefore = port.queryCapabilitiesCalls.length;
    await controller.updateDeviceId('/dev/video0');
    final state = container.read(cameraSettingsControllerProvider);
    expect(state.deviceId, '/dev/video0');
    expect(
      port.applyParamsCalls.last.deviceId,
      '/dev/video0',
      reason: '桌面设备切换经 applyParams 应用',
    );
    expect(
      port.queryCapabilitiesCalls.length,
      greaterThan(probesBefore),
      reason: '切换后重探能力',
    );
  });

  test('updateParams:控制项写入 v4l2Controls + applyParams 透传', () async {
    final controller = container.read(
      cameraSettingsControllerProvider.notifier,
    );
    await controller.probe();
    await controller.updateParams(
      const CaptureParams(
        deviceId: '/dev/video0',
        v4l2Controls: {'brightness': 10},
      ),
    );
    final state = container.read(cameraSettingsControllerProvider);
    expect(state.params.v4l2Controls['brightness'], 10);
    expect(port.applyParamsCalls.last.v4l2Controls['brightness'], 10);
  });

  test('自动白平衡开关切换 → 重探能力(active 联动刷新)', () async {
    final controller = container.read(
      cameraSettingsControllerProvider.notifier,
    );
    await controller.probe();
    final probesBefore = port.queryCapabilitiesCalls.length;
    final wbParams = const CaptureParams(
      deviceId: '/dev/video0',
      v4l2Controls: {'white_balance_automatic': 0},
    );
    await controller.updateParams(wbParams);
    expect(
      port.queryCapabilitiesCalls.length,
      greaterThan(probesBefore),
      reason: '白平衡开关变更触发重探',
    );
    // 非联动参数(亮度,累积式 copyWith 与 UI 一致)不触发重探
    final before2 = port.queryCapabilitiesCalls.length;
    await controller.updateParams(
      wbParams.copyWith(
        v4l2Controls: {...wbParams.v4l2Controls, 'brightness': 5},
      ),
    );
    expect(port.queryCapabilitiesCalls.length, before2);
  });
}

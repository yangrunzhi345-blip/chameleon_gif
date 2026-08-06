import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_port_impl.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

/// 相机设置分组状态。
class CameraSettingsState {
  const CameraSettingsState({
    this.params = const CaptureParams(),
    this.deviceId = 'back',
    this.devices = const [],
    this.capabilities,
    this.probing = false,
  });

  final CaptureParams params;
  final String deviceId;
  final List<CameraDevice> devices;

  /// 能力探测结果(null = 探测失败/进行中,分组降级显示基础参数)。
  final CameraCapabilities? capabilities;
  final bool probing;

  CameraSettingsState copyWith({
    CaptureParams? params,
    String? deviceId,
    List<CameraDevice>? devices,
    CameraCapabilities? capabilities,
    bool? probing,
  }) {
    return CameraSettingsState(
      params: params ?? this.params,
      deviceId: deviceId ?? this.deviceId,
      devices: devices ?? this.devices,
      capabilities: capabilities ?? this.capabilities,
      probing: probing ?? this.probing,
    );
  }
}

/// 相机设置控制器(设置页分组;autoDispose,会话级)。
///
/// 进入设置页 [probe] 一次:载入持久化参数 → 枚举设备 → 能力探测 →
/// 保持相机会话(live apply 体验增强);参数变更即 applyParams;save
/// 持久化(capture_params / capture_device_id);dispose 释放相机会话。
class CameraSettingsController extends Notifier<CameraSettingsState> {
  CameraPort? _port;
  bool _probing = false;

  @override
  CameraSettingsState build() {
    // 会话生命周期内捕获端口引用;dispose 时释放相机会话(仅 Android,
    // 避免 read 已销毁树)
    final port = ref.watch(cameraPortProvider);
    _port = port;
    ref.onDispose(() {
      if (port is CameraPortImpl) unawaited(port.releaseController());
    });
    final repo = ref.read(settingsRepositoryProvider);
    return CameraSettingsState(
      params: repo.captureParams ?? const CaptureParams(),
      deviceId: repo.captureDeviceId,
    );
  }

  /// 异步能力探测(枚举设备 + queryCapabilities;失败降级,防重入)。
  Future<void> probe() async {
    if (_probing) return;
    _probing = true;
    state = state.copyWith(probing: true);
    try {
      final devices = await _port?.enumerateDevices() ?? const <CameraDevice>[];
      if (!ref.mounted) return;
      state = state.copyWith(devices: devices);
      var deviceId = state.deviceId;
      if (devices.isNotEmpty && !devices.any((d) => d.id == deviceId)) {
        deviceId = devices.first.id;
        state = state.copyWith(deviceId: deviceId);
      }
      final caps = await _port?.queryCapabilities(deviceId);
      if (!ref.mounted) return;
      state = state.copyWith(capabilities: caps, probing: false);
    } catch (_) {
      // 探测失败降级:保持基础参数,probing 复位
      if (ref.mounted) state = state.copyWith(probing: false);
    } finally {
      _probing = false;
    }
  }

  /// 参数变更(立即 applyParams 到会话;保存动作由设置页统一触发)。
  Future<void> updateParams(CaptureParams params) async {
    final prevControls = state.params.v4l2Controls;
    final nextControls = params.v4l2Controls;
    // 自动白平衡开关联动:关闭后色温项 active 恢复(应用后重探刷新面板)
    final wbToggled =
        prevControls['white_balance_automatic'] !=
        nextControls['white_balance_automatic'];
    state = state.copyWith(params: params);
    await _port?.applyParams(params);
    if (wbToggled) await probe();
  }

  Future<void> updateDeviceId(String deviceId) async {
    state = state.copyWith(deviceId: deviceId);
    final port = _port;
    if (port == null) return;
    if (port is CameraPortImpl) {
      await port.ensureController(deviceId: deviceId); // Android 会话重建
    } else {
      // 桌面:设备即采集输入,切换即应用(枚举能力随之重探)
      await port.applyParams(state.params.copyWith(deviceId: deviceId));
      await probe();
    }
  }

  /// 持久化当前参数(设置页「保存设置」统一调用)。
  Future<void> save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setCaptureParams(
      state.params.copyWith(deviceId: state.deviceId),
    );
    await repo.setCaptureDeviceId(state.deviceId);
  }
}

final cameraSettingsControllerProvider =
    NotifierProvider.autoDispose<CameraSettingsController, CameraSettingsState>(
      CameraSettingsController.new,
    );

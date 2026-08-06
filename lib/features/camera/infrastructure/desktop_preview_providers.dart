import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'camera_port_impl.dart';

/// 桌面相机截帧预览会话(autoDispose FutureProvider)。
///
/// 生命周期收敛于此:进入拍摄页 watch → startPreview(ffmpeg image2pipe
/// 截帧进程 + JPEG 帧流);页面销毁(autoDispose 无监听)→ onDispose →
/// stopPreview(State.dispose 内不可用 ref,provider 层收敛与
/// cameraControllerProvider 同型)。
///
/// 返回 null = 不适用(Android 取景经插件 surface)/无设备/启动失败,
/// UI 走盲拍兜底(docs/18 D4 回放确认)。
final desktopPreviewFramesProvider =
    FutureProvider.autoDispose<Stream<Uint8List>?>((ref) async {
      final port = ref.watch(cameraPortProvider);
      if (port is CameraPortImpl) return null; // Android 插件取景
      final repo = ref.watch(settingsRepositoryProvider);
      final params = repo.captureParams ?? const CaptureParams();
      var deviceId = params.deviceId;
      if (deviceId == null) {
        final devices = await port.enumerateDevices();
        deviceId = devices.isEmpty ? null : devices.first.id;
      }
      if (deviceId == null) return null;
      ref.onDispose(() => unawaited(port.stopPreview()));
      return port.startPreview(deviceId: deviceId, params: params);
    });

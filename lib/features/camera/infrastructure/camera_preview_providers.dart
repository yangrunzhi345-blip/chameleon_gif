import 'dart:async';

import 'package:camera/camera.dart' show CameraController;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'camera_port_impl.dart';

/// 取景控制器(会话级 autoDispose FutureProvider;docs/18 C1-WP3)。
///
/// 页面 watch 渲染 CameraPreview;为 null(测试 override / 桌面 / 权限拒绝)
/// → 占位容器。与 [CameraPortImpl.capture] 同源复用会话控制器;
/// autoDispose 无监听(离开页面)时经 onDispose 释放相机会话(页面
/// dispose 内不可用 ref,释放收敛于此,见 CaptureScreen.dispose 注释)。
/// 参数与 [capture] 同源(仓储拍摄参数):ensureController 幂等命中同一
/// 会话,避免 capture 带 fps 触发重建导致预览持有已 dispose controller
/// (真机实测 CameraException: buildPreview on disposed,修复见提交记录)。
final cameraControllerProvider = FutureProvider.autoDispose<CameraController?>((
  ref,
) async {
  final port = ref.watch(cameraPortProvider);
  if (port is! CameraPortImpl) return null; // 测试 fake / 桌面 stub
  final params =
      ref.watch(settingsRepositoryProvider).captureParams ??
      const CaptureParams();
  ref.onDispose(() => unawaited(port.releaseController()));
  try {
    return await port.ensureController(
      deviceId: params.deviceId,
      fps: params.fps,
    );
  } catch (_) {
    return null; // 错误由 capture 出口再报(取景仅降级占位)
  }
});

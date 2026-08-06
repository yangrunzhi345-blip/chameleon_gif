/// 相机设备与能力描述(阶段 A 最小面;能力探测细化在阶段 B 落地时扩展)。
library;

import 'capture_params.dart' show FocusMode;

/// 相机设备(桌面 = 可用摄像头;Android = 前后摄)。
class CameraDevice {
  const CameraDevice({required this.id, required this.name});

  /// 设备标识(桌面 /dev/videoN 或 Windows 设备名;Android cameraId)。
  final String id;

  /// 用户可读名称。
  final String name;
}

/// 相机能力探测结果(设置页动态渲染依据;"设备支持什么显示什么")。
class CameraCapabilities {
  const CameraCapabilities({
    this.maxDurationMs = 30000,
    this.supportedFps = const [15.0],
    this.supportsFlash = true,
    this.supportsExposureOffset = false,
    this.exposureOffsetMin = -2.0,
    this.exposureOffsetMax = 2.0,
    this.exposureOffsetStep = 0.1,
    this.supportsZoom = false,
    this.zoomMin = 1.0,
    this.zoomMax = 1.0,
    this.supportsExposureLock = true,
    this.focusModes = const [FocusMode.auto, FocusMode.manual],
  });

  /// 拍摄时长上限(毫秒)。
  final int maxDurationMs;

  /// 支持的帧率列表(camera 插件无查询 API,保持默认候选)。
  final List<double> supportedFps;

  /// 是否支持闪光灯。
  final bool supportsFlash;

  /// 是否支持曝光补偿(滑条)。
  final bool supportsExposureOffset;

  /// 曝光补偿范围与步进(滑条 divisions 计算依据)。
  final double exposureOffsetMin;
  final double exposureOffsetMax;
  final double exposureOffsetStep;

  /// 是否支持变焦(滑条)。
  final bool supportsZoom;

  /// 变焦范围。
  final double zoomMin;
  final double zoomMax;

  /// 是否支持曝光锁定。
  final bool supportsExposureLock;

  /// 支持的对焦模式(Android camera 插件仅 auto/fixed,continuous 映射 auto)。
  final List<FocusMode> focusModes;
}

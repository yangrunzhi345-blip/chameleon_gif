/// 相机设备与能力描述(阶段 A 最小面;能力探测细化在阶段 B 落地时扩展)。
library;

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
    this.supportsFlash = false,
  });

  /// 拍摄时长上限(毫秒)。
  final int maxDurationMs;

  /// 支持的帧率列表。
  final List<double> supportedFps;

  /// 是否支持闪光灯。
  final bool supportsFlash;
}

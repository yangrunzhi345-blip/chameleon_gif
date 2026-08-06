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

/// 可调控制项类型(v4l2 语义;Windows dshow 后续复用)。
enum CameraControlKind { int, bool, menu }

/// 相机可调控制项能力描述(第二档参数;"设备支持什么显示什么")。
///
/// Linux 由 `v4l2-ctl -l` 输出解析(v4l2_controls_parser);int 带
/// min/max/step,menu 带 value→标签映射;[active] 为 false 表示当前
/// 不活跃(如自动白平衡开启时色温项 flags=inactive),设置面板置灰。
class CameraControlCapability {
  const CameraControlCapability({
    required this.id,
    required this.kind,
    this.min,
    this.max,
    this.step,
    this.defaultValue,
    this.value,
    this.active = true,
    this.choices,
  });

  /// 控制项标识(v4l2 控制名,如 brightness)。
  final String id;

  /// 控制项类型。
  final CameraControlKind kind;

  /// 最小值 / 最大值 / 步进(int 型)。
  final int? min;
  final int? max;
  final int? step;

  /// 出厂默认值。
  final int? defaultValue;

  /// 当前值(探测时刻快照)。
  final int? value;

  /// 当前是否可调(false = 硬件不活跃,置灰)。
  final bool active;

  /// menu 型:value → 显示标签。
  final Map<int, String>? choices;
}

/// 采集分辨率(桌面端相机;v4l2 MJPG 尺寸候选)。
class CaptureResolution {
  const CaptureResolution({required this.width, required this.height});

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is CaptureResolution &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
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
    this.supportsResolution = false,
    this.supportedResolutions = const <CaptureResolution>[],
    this.controls = const <CameraControlCapability>[],
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

  /// 桌面端:是否支持分辨率设置(Android 不设分辨率,D3 决策)。
  final bool supportsResolution;

  /// 桌面端:分辨率候选列表(空 → UI 隐藏分辨率行)。
  final List<CaptureResolution> supportedResolutions;

  /// 第二档可调控制项(桌面非空 → 设置页渲染动态面板;
  /// Android 恒空,走现有全参数面板)。
  final List<CameraControlCapability> controls;
}

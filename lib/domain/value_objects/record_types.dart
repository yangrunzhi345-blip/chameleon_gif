/// 录屏目标与能力描述(阶段 A 最小面;窗口枚举细化在阶段 C 落地时扩展)。
library;

/// 录制目标类型(显示器/窗口)。
enum RecordTargetKind { screen, window }

/// 桌面录屏采集方式(环境探测结果,record_environment_detector)。
enum RecordCaptureMethod {
  /// 无可用采集方式(环境不支持)。
  none,

  /// Linux X11 会话,`ffmpeg -f x11grab`。
  x11grab,

  /// Linux Wayland 会话,`ffmpeg -f pipewire`(依赖 portal 授权)。
  pipewire,

  /// Windows,`ffmpeg -f gdigrab`。
  gdigrab,
}

/// 录制目标(显示器列表与可抓窗口;窗口枚举失败时回退全屏)。
class RecordTarget {
  const RecordTarget({
    required this.id,
    required this.title,
    this.kind = RecordTargetKind.screen,
  });

  /// 目标标识(显示器序号 / 窗口句柄或标题)。
  final String id;

  /// 用户可读标题。
  final String title;

  /// 目标类型。
  final RecordTargetKind kind;
}

/// 录屏环境能力探测(X11/Wayland 判定、pipewire/gdigrab 可用性)。
class RecordCapabilities {
  const RecordCapabilities({
    this.screenCaptureAvailable = true,
    this.captureMethod = RecordCaptureMethod.none,
    this.requiresSystemConsent = false,
    this.supportsRegions = false,
    this.supportsCursorToggle = false,
    this.hint,
  });

  /// 当前环境是否具备屏幕采集能力(不可用时 UI 置灰 + 指引)。
  final bool screenCaptureAvailable;

  /// 当前环境应使用的采集方式(桌面探测结果;Android 为 none)。
  final RecordCaptureMethod captureMethod;

  /// 是否需要系统授权弹窗(Android MediaProjection 每次录制需授权;
  /// 桌面 gdigrab/x11grab/pipewire 无,pipewire 的 portal 弹窗属系统共享
  /// 选择,不算本字段语义)。
  final bool requiresSystemConsent;

  /// 是否支持区域/窗口录制(gdigrab/x11grab 支持自定义区域;
  /// pipewire 与 Android 不支持,区域 UI 隐藏)。
  final bool supportsRegions;

  /// 是否支持光标开关(gdigrab 恒带光标;x11grab 经 -draw_mouse)。
  final bool supportsCursorToggle;

  /// 用户可读环境指引(如 Wayland 缺 pipewire demuxer → 置灰 tooltip)。
  final String? hint;
}

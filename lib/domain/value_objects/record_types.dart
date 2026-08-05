/// 录屏目标与能力描述(阶段 A 最小面;窗口枚举细化在阶段 C 落地时扩展)。
library;

/// 录制目标类型(显示器/窗口)。
enum RecordTargetKind { screen, window }

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
  const RecordCapabilities({this.screenCaptureAvailable = true});

  /// 当前环境是否具备屏幕采集能力(不可用时 UI 置灰 + 指引)。
  final bool screenCaptureAvailable;
}

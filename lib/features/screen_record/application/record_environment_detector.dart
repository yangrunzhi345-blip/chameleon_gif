/// 录屏环境探测(docs/19 S3-WP1;纯函数,可单测)。
///
/// 环境判定仅基于会话类型与 DISPLAY,不跑进程;pipewire demuxer 等
/// 能力探测归 FfmpegScreenRecorder.queryCapabilities(轻量子进程)。
library;

import '../../../domain/value_objects/record_types.dart';

/// 环境探测结果。
class RecordEnvironment {
  const RecordEnvironment({required this.method, this.display});

  /// 应使用的采集方式([RecordCaptureMethod.none] = 不可用)。
  final RecordCaptureMethod method;

  /// X11 分支的 DISPLAY 值(如 ':1';x11grab 输入地址前缀)。
  final String? display;
}

/// 会话类型判定:
///
/// - `wayland` → [RecordCaptureMethod.pipewire](ffmpeg 6.1+ 输入,需
///   xdg-desktop-portal 授权,权限弹窗属系统共享选择);
/// - `x11` → [RecordCaptureMethod.x11grab],display 透传;
/// - 无 session 类型但 display 非空 → 兜底视为 X11(测试/无桌面注入
///   场景,如 CI);两者皆缺 → none(Windows 由实现层另行选 gdigrab)。
RecordEnvironment detectRecordEnvironment({
  required String? sessionType,
  required String? display,
}) {
  switch (sessionType?.toLowerCase()) {
    case 'wayland':
      return const RecordEnvironment(method: RecordCaptureMethod.pipewire);
    case 'x11':
      return RecordEnvironment(
        method: RecordCaptureMethod.x11grab,
        display: display,
      );
    default:
      if (display != null && display.isNotEmpty) {
        return RecordEnvironment(
          method: RecordCaptureMethod.x11grab,
          display: display,
        );
      }
      return const RecordEnvironment(method: RecordCaptureMethod.none);
  }
}

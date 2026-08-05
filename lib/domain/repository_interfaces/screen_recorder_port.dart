import '../value_objects/capture_result.dart';
import '../value_objects/record_params.dart';
import '../value_objects/record_types.dart';
import 'ffmpeg_engine.dart';

/// 录屏端口(docs/19 §3.2;平台实现:Android MediaProjection /
/// 桌面 gdigrab/x11grab/pipewire,阶段 B/C 落地)。
abstract interface class ScreenRecorderPort {
  /// 目标枚举:显示器列表(Windows 多屏/桌面会话)与可抓窗口(Windows)。
  Future<List<RecordTarget>> enumerateTargets();

  /// 环境探测(X11/Wayland 判定、pipewire/gdigrab 可用性)。
  Future<RecordCapabilities> queryCapabilities();

  /// 录制:产物落位(Android 转存相册),返回最终路径/URI。
  ///
  /// 取消经 [cancelToken] 协商(语义同 [CameraPort.capture])。
  Future<CaptureResult> record({
    required RecordParams params,
    CancelToken? cancelToken,
  });
}

import '../value_objects/camera_types.dart';
import '../value_objects/capture_params.dart';
import '../value_objects/capture_result.dart';
import 'ffmpeg_engine.dart';

/// 相机拍摄端口(docs/18 §5.2;平台实现:Android camera 插件 /
/// 桌面 ffmpeg 采集 + v4l2-ctl/COM 控制,阶段 B/C 落地)。
abstract interface class CameraPort {
  /// 设备枚举:桌面返回可用摄像头列表;Android 返回前后摄。
  Future<List<CameraDevice>> enumerateDevices();

  /// 能力探测(控制项/分辨率/帧率支持范围;设置页动态渲染依据)。
  Future<CameraCapabilities> queryCapabilities(String deviceId);

  /// 设置参数(设置页改动即时生效;Android 插件级,桌面 v4l2-ctl/COM)。
  Future<void> applyParams(CaptureParams params);

  /// 拍摄:录像到素材文件并落位(Android 转存相册),返回最终路径/URI。
  ///
  /// 取消经 [cancelToken] 协商(轮询 [CancelToken.isCancelled] +
  /// [CancelToken.onCancel] 注册停止回调,与 ProcessEngine 同型);
  /// 实现方负责清理临时产物。
  Future<CaptureResult> capture({
    required CaptureParams params,
    CancelToken? cancelToken,
  });
}

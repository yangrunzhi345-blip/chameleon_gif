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

  /// 是否支持实时取景预览(Android 取景框;桌面盲拍 → false,
  /// 录完在工作台回放确认,docs/18 D4)。同步 getter,零副作用:
  /// 拍摄页取景形态是端口级恒定属性,不应付 queryCapabilities
  /// 的会话初始化代价(Android 该探测会建立相机会话)。
  bool get previewSupported;

  /// 手动停止当前录制(保存;录制中由页面停止按钮调用)。
  ///
  /// 与 [capture] 的 [cancelToken] 取消语义对立:停止 = 正常保存结束,
  /// 取消 = 清理临时产物不落位。
  Future<void> requestStop();

  /// 启动实时预览(docs/18 里程碑 4;桌面流预览:ffmpeg 推 UDP 流,
  /// media_kit 播放)。
  ///
  /// 返回预览流地址(如 `udp://127.0.0.1:PORT?pkt_size=1316`);null =
  /// 启动失败或不适用(Android 无此路径,恒 null)。幂等:同设备同参数
  /// 已预览 → 直接返回现有地址。
  Future<String?> startPreview({
    required String deviceId,
    required CaptureParams params,
  });

  /// 停止实时预览(幂等;录制开始前由 [capture] 内部收敛 —— v4l2 设备
  /// 独占,预览与采集不可并存)。
  Future<void> stopPreview();
}

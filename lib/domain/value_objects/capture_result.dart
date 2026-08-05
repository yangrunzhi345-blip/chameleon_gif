import '../../shared/platform/gallery_save_result.dart';

/// 采集结果(拍摄/录屏共用,docs/18 §5.2、docs/19 §3.2)。
///
/// [finalPath] 语义:Android = 相册展示路径/内容 URI(存相册成功后),
/// 桌面 = 素材文件绝对路径;供自动导入链路与历史记录引用。
/// [galleryStatus] 三态复用 [GallerySaveResult](存相册失败不阻塞采集完成,
/// 私有副本保留供手动处理);瞬态运行结果,不落库,手写 const 类
/// (仿 GallerySaveResult 先例,非 freezed)。
class CaptureResult {
  const CaptureResult({
    required this.finalPath,
    required this.durationMs,
    this.galleryStatus = GallerySaveStatus.unsupported,
    this.galleryUri,
  });

  /// 供导入链路/历史记录引用的最终路径(相册路径/URI 或素材文件路径)。
  final String finalPath;

  /// 实际录制时长(毫秒)。
  final int durationMs;

  /// 存相册结果三态(默认 unsupported = 桌面不写相册)。
  final GallerySaveStatus galleryStatus;

  /// 相册条目 content URI(定位用;saved 时非空)。
  final String? galleryUri;
}

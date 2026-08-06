import '../../shared/platform/gallery_save_result.dart';

/// 采集结果(拍摄/录屏共用,docs/18 §5.2、docs/19 §3.2)。
///
/// [finalPath] 语义:Android = **应用素材目录的真实文件路径**
/// (`<docsDir>/chameleon_gif/captures/`,docs/18 D1 素材持久可重转;
/// ffprobe/转换/历史重转直接可用,ffmpeg-kit 无法解析相册 content URI,
/// 阶段 B 决策 3),桌面 = 素材文件绝对路径;[galleryUri] 为相册展示副本
/// 的 content URI(定位用)。[galleryStatus] 三态复用 [GallerySaveResult]
/// (存相册失败不阻塞采集完成,素材副本保留);瞬态运行结果,不落库,
/// 手写 const 类(仿 GallerySaveResult 先例,非 freezed)。
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

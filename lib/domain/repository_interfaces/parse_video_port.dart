import '../entities/video_info.dart';

/// 视频元数据解析端口(docs/06-模块设计.md §6.1 M01 的 Domain 接口)。
///
/// ffprobe 实现位于 features/converter/infrastructure,
/// import 模块经此端口消费解析能力(依赖倒置,双方只依赖 domain)。
abstract interface class ParseVideoPort {
  /// 解析视频元数据;失败抛 [FilePickException] 子类
  /// ([SourceBrokenException] / [SourceMissingException])。
  Future<VideoInfo> parse(String path);
}

import '../exceptions/file_pick_exception.dart';

/// 图片尺寸探测端口(功能层纯 Dart;图片→GIF 命令构造的输入,
/// 未指定宽高时需统一分辨率,见 docs/08 §8.3.2.1)。
///
/// 实现位于 infrastructure(dart:ui 解码);失败抛 [FilePickException]
/// (GIF_IMAGE_PROBE_FAILED)。
abstract interface class ImageProbePort {
  /// 返回图片解码尺寸;失败抛 [FilePickException]。
  Future<({int width, int height})> probe(String path);
}

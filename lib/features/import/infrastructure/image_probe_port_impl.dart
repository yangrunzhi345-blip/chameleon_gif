import 'dart:io';
import 'dart:ui' as ui;

import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/repository_interfaces/image_probe_port.dart';

/// [ImageProbePort] 的 dart:ui 解码实现(infrastructure 允许 Flutter 依赖;
/// 首图尺寸供命令构造统一各图分辨率,见 docs/08 §8.3.2.1)。
class ImageProbePortImpl implements ImageProbePort {
  const ImageProbePortImpl();

  @override
  Future<({int width, int height})> probe(String path) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      final bytes = await File(path).readAsBytes();
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
      return (width: frame.image.width, height: frame.image.height);
    } catch (e) {
      throw FilePickException(
        errorCode: 'GIF_IMAGE_PROBE_FAILED',
        userMessage: '无法读取图片尺寸,请更换图片',
        cause: e,
      );
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }
}

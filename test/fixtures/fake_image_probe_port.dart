import 'package:chameleon_gif/domain/repository_interfaces/image_probe_port.dart';

/// [ImageProbePort] 测试替身(可配尺寸/错误,calls 记录探测调用)。
class FakeImageProbePort implements ImageProbePort {
  FakeImageProbePort({this.width = 640, this.height = 480, this.error});

  int width;
  int height;

  /// 非空时探测抛错(模拟解码失败)。
  Object? error;

  final probeCalls = <String>[];

  @override
  Future<({int width, int height})> probe(String path) async {
    probeCalls.add(path);
    if (error != null) throw error!;
    return (width: width, height: height);
  }
}

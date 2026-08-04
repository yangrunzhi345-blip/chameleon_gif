import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/shared/platform/ffmpeg_kit_engine.dart';

void main() {
  group('FfmpegKitEngine.assembleCommand', () {
    test('ffmpeg 前缀 + 空格拼接(Kit 契约)', () {
      expect(
        FfmpegKitEngine.assembleCommand([
          '-i',
          'a.mp4',
          '-frames:v',
          '1',
          '-y',
          'out.gif',
        ]),
        'ffmpeg -i a.mp4 -frames:v 1 -y out.gif',
      );
    });

    test('空参数列表仅前缀', () {
      expect(FfmpegKitEngine.assembleCommand([]), 'ffmpeg');
    });
  });
}

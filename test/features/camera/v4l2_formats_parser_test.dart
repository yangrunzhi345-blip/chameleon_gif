import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/camera/application/v4l2_formats_parser.dart';

/// v4l2-ctl --list-formats-ext 输出解析(夹具为本机真实输出固化)。
void main() {
  group('本机夹具(formats_ext.txt)', () {
    late List<V4l2FormatEntry> entries;

    setUpAll(() {
      final raw = File('test/fixtures/v4l2/formats_ext.txt').readAsStringSync();
      entries = parseV4l2FormatsExt(raw);
    });

    test('MJPG 与 YUYV 两格式分段解析', () {
      expect(entries.map((e) => e.format).toSet(), {'MJPG', 'YUYV'});
    });

    test('MJPG 1280x720 帧率 30;YUYV 1280x720 帧率 10', () {
      final mjpg = entries.firstWhere(
        (e) => e.format == 'MJPG' && e.width == 1280,
      );
      expect(mjpg.frameRates, [30.0]);
      final yuyv = entries.firstWhere(
        (e) => e.format == 'YUYV' && e.width == 1280,
      );
      expect(yuyv.frameRates, [10.0]);
    });

    test('640x480 两格式均 30fps;尺寸按出现顺序', () {
      final mjpg640 = entries.firstWhere(
        (e) => e.format == 'MJPG' && e.width == 640,
      );
      expect(mjpg640.height, 480);
      expect(mjpg640.frameRates, [30.0]);
      // MJPG 6 个 Discrete 尺寸
      expect(entries.where((e) => e.format == 'MJPG'), hasLength(6));
    });
  });

  test('空输出 → 空列表', () {
    expect(parseV4l2FormatsExt(''), isEmpty);
  });

  test('Stepwise/Continuous 尺寸与帧率跳过', () {
    const raw = '''
	[0]: 'MJPG' (Motion-JPEG, compressed)
		Size: Discrete 640x480
			Interval: Discrete 0.033s (30.000 fps)
		Size: Stepwise 320x240 - 1920x1080 step 160x120
			Interval: Continuous 0.033s - 0.100s
''';
    final entries = parseV4l2FormatsExt(raw);
    expect(entries, hasLength(1));
    expect(entries.single.width, 640);
    expect(entries.single.frameRates, [30.0]);
  });
}

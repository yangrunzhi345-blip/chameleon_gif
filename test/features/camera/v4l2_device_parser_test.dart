import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/camera/application/v4l2_device_parser.dart';

/// v4l2/dshow 设备枚举输出解析(纯函数;夹具为本机真实输出固化)。
void main() {
  group('parseV4l2ListDevices', () {
    test('本机夹具:过滤 /dev/media*,保留两个 video 节点', () {
      final raw = File(
        'test/fixtures/v4l2/list_devices.txt',
      ).readAsStringSync();
      final entries = parseV4l2ListDevices(raw);
      expect(entries, hasLength(2));
      expect(
        entries[0].name,
        'USB2.0 HD UVC WebCam: USB2.0 HD (usb-0000:36:00.3-4)',
      );
      expect(entries[0].node, '/dev/video0');
      expect(entries[1].node, '/dev/video1');
    });

    test('多设备分组:每个设备名独立分组', () {
      const raw = '''
Webcam A:
\t/dev/video0

Webcam B:
\t/dev/video2
\t/dev/media1
''';
      final entries = parseV4l2ListDevices(raw);
      expect(entries, hasLength(2));
      expect(entries[0].name, 'Webcam A');
      expect(entries[0].node, '/dev/video0');
      expect(entries[1].name, 'Webcam B');
      expect(entries[1].node, '/dev/video2');
    });

    test('无设备 → 空列表', () {
      expect(parseV4l2ListDevices(''), isEmpty);
      expect(parseV4l2ListDevices('无法打开 /dev/video0: No such file'), isEmpty);
    });
  });

  group('parseFfmpegSourcesV4l2', () {
    test('本机夹具:解析节点与方括号内名称', () {
      final raw = File(
        'test/fixtures/v4l2/ffmpeg_sources_v4l2.txt',
      ).readAsStringSync();
      final entries = parseFfmpegSourcesV4l2(raw);
      expect(entries, hasLength(2));
      expect(entries[0].node, '/dev/video1');
      expect(entries[0].name, 'USB2.0 HD UVC WebCam: USB2.0 HD');
      expect(entries[1].node, '/dev/video0');
    });

    test('空输出 → 空列表', () {
      expect(parseFfmpegSourcesV4l2(''), isEmpty);
    });
  });

  group('parseFfmpegSourcesDshow', () {
    test('夹具:仅 video 段,音频段截断', () {
      final raw = File(
        'test/fixtures/ffmpeg_sources_dshow.txt',
      ).readAsStringSync();
      final names = parseFfmpegSourcesDshow(raw);
      expect(names, ['Integrated Camera', 'OBS Virtual Camera']);
    });

    test('设备名含空格与括号保留原样', () {
      const raw = '''
DirectShow video devices (some may be both video and audio devices)
    "HD Pro Webcam C920 (03f0:0294)"
''';
      expect(parseFfmpegSourcesDshow(raw), ['HD Pro Webcam C920 (03f0:0294)']);
    });
  });
}

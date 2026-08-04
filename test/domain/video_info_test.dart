import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';

void main() {
  const info = VideoInfo(
    path: '/tmp/sample.mp4',
    formatName: 'mov,mp4,m4a,3gp,3g2,mj2',
    duration: Duration(seconds: 10, milliseconds: 533),
    width: 640,
    height: 360,
    fps: 29.97,
    codec: 'h264',
  );

  group('VideoInfo 序列化', () {
    test('toJson 字段名与类型正确(duration 为微秒 int)', () {
      final json = info.toJson();
      expect(json['path'], '/tmp/sample.mp4');
      expect(json['formatName'], 'mov,mp4,m4a,3gp,3g2,mj2');
      expect(json['duration'], 10533000);
      expect(json['width'], 640);
      expect(json['height'], 360);
      expect(json['fps'], 29.97);
      expect(json['codec'], 'h264');
    });

    test('fromJson/toJson 往返一致', () {
      final decoded = VideoInfo.fromJson(
        jsonDecode(jsonEncode(info.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, info);
    });

    test('fromJson 可经 JSON 字符串编解码(与 Isar 快照兼容)', () {
      final map = jsonDecode(jsonEncode(info.toJson())) as Map<String, dynamic>;
      final decoded = VideoInfo.fromJson(map);
      expect(decoded.duration, const Duration(seconds: 10, milliseconds: 533));
      expect(decoded.fps, 29.97);
    });

    test('required 字段缺失时抛错', () {
      expect(
        () => VideoInfo.fromJson({'path': '/tmp/a.mp4'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('copyWith 只改指定字段', () {
      final copied = info.copyWith(width: 1920, fps: null);
      expect(copied.width, 1920);
      expect(copied.fps, isNull);
      expect(copied.height, 360);
      expect(copied.path, '/tmp/sample.mp4');
    });

    test('fps 可空字段序列化为 null', () {
      const noFps = VideoInfo(
        path: '/tmp/a.mp4',
        formatName: 'mp4',
        duration: Duration.zero,
        width: 1,
        height: 1,
        codec: 'h264',
      );
      expect(noFps.toJson()['fps'], isNull);
      expect(VideoInfo.fromJson(noFps.toJson()).fps, isNull);
    });
  });
}

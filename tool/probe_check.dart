// 常驻验证脚本:P1 阶段门真实样本验证(依赖系统 ffprobe + /tmp/gifforge_p1 样本)。
//
// 运行:dart run tool/probe_check.dart
// 全部通过退出 0;任一断言失败打印明细并退出 1。
import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/exceptions/source_missing_exception.dart';
import 'package:chameleon_gif/features/converter/infrastructure/ffprobe_parse_video_port.dart';

const kSamples = [
  (
    name: '30fps 320x240',
    path: '/tmp/gifforge_p1/sample_30fps.mp4',
    durationMs: 2000,
    width: 320,
    height: 240,
    fps: 30.0,
    codec: 'h264',
  ),
  (
    name: '60fps 640x360',
    path: '/tmp/gifforge_p1/sample_60fps.mp4',
    durationMs: null,
    width: 640,
    height: 360,
    fps: 60.0,
    codec: null,
  ),
  (
    name: '25fps 竖屏 360x640',
    path: '/tmp/gifforge_p1/sample_portrait_25fps.mp4',
    durationMs: null,
    width: 360,
    height: 640,
    fps: 25.0,
    codec: null,
  ),
  (
    name: '1080p 30fps',
    path: '/tmp/gifforge_p1/sample_1080p.mp4',
    durationMs: null,
    width: 1920,
    height: 1080,
    fps: 30.0,
    codec: null,
  ),
  (
    name: '带音轨',
    path: '/tmp/gifforge_p1/sample_with_audio.mp4',
    durationMs: null,
    width: 640,
    height: 360,
    fps: 30.0,
    codec: null,
  ),
  (
    name: '10fps 低分辨率',
    path: '/tmp/gifforge_p1/sample_lowres.mp4',
    durationMs: null,
    width: 160,
    height: 120,
    fps: 10.0,
    codec: null,
  ),
];

const kBrokenSamples = [
  (
    name: '截断 mp4',
    path: '/tmp/gifforge_p1/broken_truncated.mp4',
    type: SourceBrokenException,
  ),
  (
    name: '文本伪装 mp4',
    path: '/tmp/gifforge_p1/broken_text.mp4',
    type: SourceBrokenException,
  ),
  (
    name: '文件不存在',
    path: '/tmp/gifforge_p1/no_such_file.mp4',
    type: SourceMissingException,
  ),
];

void main() async {
  final port = FfprobeParseVideoPort(logger: AppLogger());
  var failures = 0;

  for (final s in kSamples) {
    try {
      final info = await port.parse(s.path);
      final errors = <String>[];
      if (s.durationMs != null &&
          info.duration.inMilliseconds != s.durationMs) {
        errors.add(
          'duration=${info.duration.inMilliseconds}ms != ${s.durationMs}ms',
        );
      }
      if (info.width != s.width) {
        errors.add('width=${info.width} != ${s.width}');
      }
      if (info.height != s.height) {
        errors.add('height=${info.height} != ${s.height}');
      }
      if (info.fps != s.fps) {
        errors.add('fps=${info.fps} != ${s.fps}');
      }
      if (s.codec != null && info.codec != s.codec) {
        errors.add('codec=${info.codec} != ${s.codec}');
      }
      if (errors.isEmpty) {
        // ignore: avoid_print
        print(
          'OK  ${s.name} → ${info.duration.inMilliseconds}ms '
          '${info.width}x${info.height} fps=${info.fps} codec=${info.codec}',
        );
      } else {
        failures++;
        // ignore: avoid_print
        print('FAIL ${s.name} → ${errors.join('; ')}');
      }
    } catch (e) {
      failures++;
      // ignore: avoid_print
      print('FAIL ${s.name} → 异常: $e');
    }
  }

  for (final s in kBrokenSamples) {
    try {
      await port.parse(s.path);
      failures++;
      // ignore: avoid_print
      print('FAIL ${s.name} → 未抛异常!');
    } catch (e) {
      if (s.type == e.runtimeType) {
        // ignore: avoid_print
        print('EXP  ${s.name} → ${e.runtimeType}: $e');
      } else {
        failures++;
        // ignore: avoid_print
        print('FAIL ${s.name} → 期望 ${s.type},实际 ${e.runtimeType}: $e');
      }
    }
  }

  // ignore: avoid_print
  print(
    failures == 0
        ? 'PASS 全部通过 (${kSamples.length + kBrokenSamples.length} 项)'
        : 'FAILED $failures 项',
  );
  exit(failures == 0 ? 0 : 1);
}

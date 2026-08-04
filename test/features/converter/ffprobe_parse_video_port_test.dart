import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/features/converter/infrastructure/ffprobe_parse_video_port.dart';

import '../../fixtures/ffprobe_loader.dart';

void main() {
  final port = FfprobeParseVideoPort(logger: AppLogger());

  group('assemble 决策汇聚', () {
    test('成功 + MediaInformation → VideoInfo', () {
      final info = port.assemble(
        isSuccess: true,
        exitCode: 0,
        stderr: '',
        mediaInfo: loadFfprobeFixture('h264_640x360_29.97'),
        path: '/tmp/sample.mp4',
      );
      expect(info.width, 640);
      expect(info.duration, const Duration(milliseconds: 10533));
    });

    test('失败 + 损坏特征 stderr → SourceBroken(经分类器)', () {
      expect(
        () => port.assemble(
          isSuccess: false,
          exitCode: 1,
          stderr: 'Invalid data found when processing input',
          mediaInfo: null,
          path: '/tmp/a.mp4',
        ),
        throwsA(isA<SourceBrokenException>()),
      );
    });

    test('成功但 mediaInfo 为空 → 兜底异常', () {
      expect(
        () => port.assemble(
          isSuccess: true,
          exitCode: 0,
          stderr: '',
          mediaInfo: null,
          path: '/tmp/a.mp4',
        ),
        throwsA(
          isA<FilePickException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_0_PROBE_FAILED',
          ),
        ),
      );
    });

    test('exitCode 255(取消)→ 取消异常', () {
      expect(
        () => port.assemble(
          isSuccess: false,
          exitCode: 255,
          stderr: '',
          mediaInfo: null,
          path: '/tmp/a.mp4',
        ),
        throwsA(
          isA<FilePickException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_255_PROBE_CANCELLED',
          ),
        ),
      );
    });
  });
}

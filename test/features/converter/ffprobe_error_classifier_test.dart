import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/exceptions/source_missing_exception.dart';
import 'package:gif_forge/features/converter/infrastructure/ffprobe_error_classifier.dart';

void main() {
  const classifier = FfprobeErrorClassifier();

  group('FfprobeErrorClassifier 特征映射', () {
    test('No such file or directory → SourceMissing + 错误码', () {
      final e = classifier.classify(
        stderr: 'ffprobe: file.mp4: No such file or directory',
        exitCode: 1,
      );
      expect(e, isA<SourceMissingException>());
      expect(e.errorCode, 'GIF_1_SOURCE_MISSING');
      expect(e.userMessage, '源文件不存在或已被移动');
    });

    test('Invalid data found → SourceBroken', () {
      final e = classifier.classify(
        stderr: 'Invalid data found when processing input',
        exitCode: 1,
      );
      expect(e, isA<SourceBrokenException>());
      expect(e.errorCode, 'GIF_1_SOURCE_BROKEN');
      expect(e.userMessage, '视频文件损坏或格式异常');
    });

    test('moov atom 缺失 → SourceBroken(小写命中)', () {
      final e = classifier.classify(stderr: 'moov atom not found', exitCode: 1);
      expect(e, isA<SourceBrokenException>());
    });

    test('MOOV 大小写变体命中', () {
      final e = classifier.classify(
        stderr: 'Cannot find MOOV atom in file.mp4',
        exitCode: 1,
      );
      expect(e, isA<SourceBrokenException>());
    });

    test('exitCode 参与错误码前缀(GIF_<EXITCODE>_<KIND>)', () {
      final e = classifier.classify(
        stderr: 'Invalid data found when processing input',
        exitCode: 2,
      );
      expect(e.errorCode, 'GIF_2_SOURCE_BROKEN');
    });

    test('未匹配特征 → FilePickException 兜底', () {
      final e = classifier.classify(
        stderr: 'some unknown error happened',
        exitCode: 1,
      );
      expect(e, isA<FilePickException>());
      expect(e.errorCode, 'GIF_1_PROBE_FAILED');
      expect(e.userMessage, contains('请尝试其他文件'));
    });

    test('空 stderr → 兜底', () {
      final e = classifier.classify(stderr: '', exitCode: 3);
      expect(e.errorCode, 'GIF_3_PROBE_FAILED');
    });

    test('missing 特征优先于 broken(匹配顺序)', () {
      final e = classifier.classify(
        stderr: 'No such file or directory: moov atom not found',
        exitCode: 1,
      );
      expect(e, isA<SourceMissingException>());
    });
  });
}

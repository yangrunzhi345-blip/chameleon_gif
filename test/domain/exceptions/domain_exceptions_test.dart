import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/domain_exception.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/exceptions/source_missing_exception.dart';

void main() {
  group('异常层级与构造', () {
    test('继承链:SourceBroken → FilePick → Domain → Exception', () {
      const e = SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
      expect(e, isA<FilePickException>());
      expect(e, isA<DomainException>());
      expect(e, isA<Exception>());
    });

    test('SourceBroken 携带固定中文文案与错误码', () {
      const e = SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
      expect(e.userMessage, '视频文件损坏或格式异常');
      expect(e.errorCode, 'GIF_1_SOURCE_BROKEN');
    });

    test('SourceMissing 携带固定中文文案与错误码', () {
      const e = SourceMissingException(errorCode: 'GIF_1_SOURCE_MISSING');
      expect(e.userMessage, '源文件不存在或已被移动');
      expect(e.errorCode, 'GIF_1_SOURCE_MISSING');
    });

    test('cause 透传供日志排查', () {
      final cause = StateError('底层原因');
      final e = SourceBrokenException(
        errorCode: 'GIF_1_SOURCE_BROKEN',
        cause: cause,
      );
      expect(e.cause, same(cause));
    });

    test('FilePickException 兜底可携带自定义文案', () {
      const e = FilePickException(
        errorCode: 'GIF_1_PROBE_FAILED',
        userMessage: '视频解析失败(错误码 1),请尝试其他文件',
      );
      expect(e.errorCode, 'GIF_1_PROBE_FAILED');
      expect(e.userMessage, '视频解析失败(错误码 1),请尝试其他文件');
    });

    test('toString 包含错误码便于日志检索', () {
      const e = SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
      expect(e.toString(), contains('GIF_1_SOURCE_BROKEN'));
      expect(e.toString(), contains('视频文件损坏或格式异常'));
    });
  });
}

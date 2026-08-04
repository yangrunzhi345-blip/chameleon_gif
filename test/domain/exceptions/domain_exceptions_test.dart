import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/conversion_exception.dart';
import 'package:gif_forge/domain/exceptions/disk_full_exception.dart';
import 'package:gif_forge/domain/exceptions/domain_exception.dart';
import 'package:gif_forge/domain/exceptions/encode_exception.dart';
import 'package:gif_forge/domain/exceptions/ffmpeg_missing_exception.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/output_conflict_exception.dart';
import 'package:gif_forge/domain/exceptions/palette_exception.dart';
import 'package:gif_forge/domain/exceptions/permission_exception.dart';
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

    test('FFmpegMissing 默认 PROBE 错误码(P1 兼容)', () {
      const e = FFmpegMissingException();
      expect(e.errorCode, 'GIF_127_PROBE_MISSING');
    });

    test('FFmpegMissing kind=ENCODE 错误码(P3 转码)', () {
      const e = FFmpegMissingException(kind: 'ENCODE');
      expect(e.errorCode, 'GIF_127_ENCODE_MISSING');
    });

    test('转换异常族继承链:Encode → Conversion → Domain → Exception', () {
      const e = EncodeException(errorCode: 'GIF_1_ENCODE');
      expect(e, isA<ConversionException>());
      expect(e, isA<DomainException>());
      expect(e, isA<Exception>());
    });

    test('五个转换异常携带固定中文文案与错误码', () {
      const diskFull = DiskFullException(errorCode: 'GIF_1_DISK_FULL');
      expect(diskFull.userMessage, '磁盘空间不足,请清理后重试');
      expect(diskFull.errorCode, 'GIF_1_DISK_FULL');

      const permission = PermissionException(errorCode: 'GIF_1_PERMISSION');
      expect(permission.userMessage, '没有文件写入权限');

      const conflict = OutputConflictException(
        errorCode: 'GIF_1_OUTPUT_CONFLICT',
      );
      expect(conflict.userMessage, '输出文件已存在');

      const palette = PaletteException(errorCode: 'GIF_1_PALETTE');
      expect(palette.userMessage, contains('调色板'));
      expect(palette.errorCode, 'GIF_1_PALETTE');

      const encode = EncodeException(errorCode: 'GIF_1_ENCODE');
      expect(encode.userMessage, isNotEmpty);
      expect(encode.errorCode, 'GIF_1_ENCODE');
    });

    test('toString 覆盖全部异常子类(日志检索契约:含错误码与用户文案)', () {
      const cases = <DomainException>[
        FilePickException(errorCode: 'GIF_1_X', userMessage: 'x'),
        ConversionException(errorCode: 'GIF_1_Y', userMessage: 'y'),
        DiskFullException(errorCode: 'GIF_1_DISK_FULL'),
        PermissionException(errorCode: 'GIF_1_PERMISSION'),
        OutputConflictException(errorCode: 'GIF_1_OUTPUT_CONFLICT'),
        PaletteException(errorCode: 'GIF_1_PALETTE'),
        EncodeException(errorCode: 'GIF_1_ENCODE'),
        FFmpegMissingException(),
        SourceMissingException(errorCode: 'GIF_1_SOURCE_MISSING'),
      ];

      for (final e in cases) {
        final s = e.toString();
        expect(s, contains(e.errorCode));
        expect(s, contains(e.userMessage));
      }
    });

    test('DomainException 基类 toString(未重写子类的继承路径)', () {
      const e = _PlainDomainException(errorCode: 'GIF_1_Z', userMessage: 'z');
      expect(e.toString(), contains('GIF_1_Z'));
      expect(e.toString(), contains('z'));
    });
  });
}

/// 不重写 toString 的最小子类:覆盖基类 [DomainException.toString] 继承路径。
class _PlainDomainException extends DomainException {
  const _PlainDomainException({
    required super.errorCode,
    required super.userMessage,
  });
}

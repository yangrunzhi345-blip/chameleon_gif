import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/conversion_exception.dart';
import 'package:gif_forge/domain/exceptions/disk_full_exception.dart';
import 'package:gif_forge/domain/exceptions/encode_exception.dart';
import 'package:gif_forge/domain/exceptions/ffmpeg_missing_exception.dart';
import 'package:gif_forge/domain/exceptions/output_conflict_exception.dart';
import 'package:gif_forge/domain/exceptions/palette_exception.dart';
import 'package:gif_forge/domain/exceptions/permission_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/exceptions/source_missing_exception.dart';
import 'package:gif_forge/features/converter/application/error_handler.dart';

/// [ErrorHandler] 错误映射表全覆盖测试(docs/08 §8.3.5,8 行映射)。
void main() {
  const handler = ErrorHandler();

  test('exit 127 → FFmpegMissingException(GIF_127_ENCODE_MISSING)', () {
    final e = handler.classify(exitCode: 127, stderr: '');
    expect(e, isA<FFmpegMissingException>());
    expect(e.errorCode, 'GIF_127_ENCODE_MISSING');
  });

  test('No such file → SourceMissingException', () {
    final e = handler.classify(
      exitCode: 1,
      stderr: 'ffmpeg: error: No such file or directory',
    );
    expect(e, isA<SourceMissingException>());
    expect(e.errorCode, 'GIF_1_SOURCE_MISSING');
  });

  test('Invalid data found → SourceBrokenException', () {
    final e = handler.classify(
      exitCode: 1,
      stderr: 'Invalid data found when processing input',
    );
    expect(e, isA<SourceBrokenException>());
    expect(e.errorCode, 'GIF_1_SOURCE_BROKEN');
  });

  test('moov 缺失(大写变体)→ SourceBrokenException', () {
    final e = handler.classify(exitCode: 1, stderr: 'moov atom not found');
    expect(e, isA<SourceBrokenException>());
    expect(e.errorCode, 'GIF_1_SOURCE_BROKEN');
  });

  test('No space left → DiskFullException', () {
    final e = handler.classify(exitCode: 1, stderr: 'No space left on device');
    expect(e, isA<DiskFullException>());
    expect(e.errorCode, 'GIF_1_DISK_FULL');
  });

  test('Permission denied → PermissionException', () {
    final e = handler.classify(exitCode: 1, stderr: 'Permission denied');
    expect(e, isA<PermissionException>());
    expect(e.errorCode, 'GIF_1_PERMISSION');
  });

  test('Output file already exists → OutputConflictException', () {
    final e = handler.classify(
      exitCode: 1,
      stderr: 'Output file already exists',
    );
    expect(e, isA<OutputConflictException>());
    expect(e.errorCode, 'GIF_1_OUTPUT_CONFLICT');
  });

  test('exit 1 + palette 关键词 → PaletteException(GIF_1_PALETTE)', () {
    final e = handler.classify(
      exitCode: 1,
      stderr: 'palettegen: Error initializing output stream',
    );
    expect(e, isA<PaletteException>());
    expect(e.errorCode, 'GIF_1_PALETTE');
  });

  test('其他非 0 → EncodeException 兜底', () {
    final e = handler.classify(exitCode: 2, stderr: 'unknown failure');
    expect(e, isA<EncodeException>());
    expect(e.errorCode, 'GIF_2_ENCODE');
    expect(e, isA<ConversionException>());
  });

  test('匹配顺序:特征行优先于 palette 兜底', () {
    final e = handler.classify(
      exitCode: 1,
      stderr: 'No space left on device palettegen failed',
    );
    expect(e, isA<DiskFullException>(), reason: '磁盘特征在前');
  });

  test('exit=2 含 palette 关键词仍走兜底(非 exit 1)', () {
    final e = handler.classify(exitCode: 2, stderr: 'paletteuse failed');
    expect(e, isA<EncodeException>());
  });
}

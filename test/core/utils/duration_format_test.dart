import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/utils/duration_format.dart';

/// [parseFfmpegTime] 时间输入解析契约(P4-WP2 表单)。
void main() {
  group('合法输入', () {
    test('HH:MM:SS.mmm', () {
      expect(parseFfmpegTime('00:03.200'), const Duration(milliseconds: 3200));
      expect(parseFfmpegTime('00:09.500'), const Duration(milliseconds: 9500));
      expect(
        parseFfmpegTime('01:02:03.456'),
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456),
      );
    });

    test('裸秒(带/不带毫秒)', () {
      expect(parseFfmpegTime('5'), const Duration(seconds: 5));
      expect(parseFfmpegTime('5.5'), const Duration(milliseconds: 5500));
      expect(parseFfmpegTime('0'), Duration.zero);
    });

    test('毫秒 1–2 位补零', () {
      expect(parseFfmpegTime('00:01.5'), const Duration(milliseconds: 1500));
      expect(parseFfmpegTime('00:01.05'), const Duration(milliseconds: 1050));
    });

    test('空白修剪', () {
      expect(
        parseFfmpegTime('  00:03.200  '),
        const Duration(milliseconds: 3200),
      );
    });
  });

  group('非法/边界', () {
    test('空串与空白 → null(到结尾语义)', () {
      expect(parseFfmpegTime(''), isNull);
      expect(parseFfmpegTime('   '), isNull);
    });

    test('分/秒 ≥60 拒绝', () {
      expect(parseFfmpegTime('00:60.000'), isNull);
      expect(parseFfmpegTime('60:00'), isNull);
      expect(parseFfmpegTime('1:2:3:4'), isNull, reason: '多余段');
    });

    test('负号/字母/乱码拒绝', () {
      expect(parseFfmpegTime('-5'), isNull);
      expect(parseFfmpegTime('abc'), isNull);
      expect(parseFfmpegTime('00:03.abc'), isNull);
      expect(parseFfmpegTime('3.4.5'), isNull);
    });
  });
}

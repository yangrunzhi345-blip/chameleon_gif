import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';

/// [captureDirPath] / [buildCaptureFilename] 纯函数测试(docs/18 §5.3)。
void main() {
  group('captureDirPath', () {
    test('类 Unix:~/Documents/chameleon_gif/captures', () {
      expect(
        captureDirPath(home: '/home/user'),
        '/home/user/Documents/chameleon_gif/captures',
      );
    });

    test('Windows:%USERPROFILE%\\Documents\\chameleon_gif\\captures', () {
      expect(
        captureDirPath(home: r'C:\Users\dev', isWindows: true),
        r'C:\Users\dev\Documents\chameleon_gif\captures',
      );
    });
  });

  group('buildCaptureFilename', () {
    final ts = DateTime(2026, 8, 6, 12, 0, 0);

    test('时间戳 + 3 位补零序号', () {
      expect(buildCaptureFilename(ts), 'capture_20260806_120000_001.mp4');
      expect(
        buildCaptureFilename(ts, seq: 12),
        'capture_20260806_120000_012.mp4',
      );
      expect(
        buildCaptureFilename(ts, seq: 999),
        'capture_20260806_120000_999.mp4',
      );
    });

    test('格式符合命名规范正则', () {
      final name = buildCaptureFilename(DateTime(2026, 1, 2, 3, 4, 5), seq: 1);
      expect(name, matches(RegExp(r'^capture_\d{8}_\d{6}_\d{3}\.mp4$')));
    });

    test('时间戳各段补零(个位月日时分秒)', () {
      expect(
        buildCaptureFilename(DateTime(2026, 1, 2, 3, 4, 5)),
        'capture_20260102_030405_001.mp4',
      );
    });
  });
}

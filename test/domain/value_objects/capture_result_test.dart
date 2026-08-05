import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';

/// [CaptureResult] 三态构造与字段(docs/18 §5.2、docs/19 §3.2 共用)。
void main() {
  test('默认 unsupported(桌面不写相册)', () {
    const r = CaptureResult(
      finalPath: '/tmp/captures/capture_1.mp4',
      durationMs: 5000,
    );
    expect(r.finalPath, '/tmp/captures/capture_1.mp4');
    expect(r.durationMs, 5000);
    expect(r.galleryStatus, GallerySaveStatus.unsupported);
    expect(r.galleryUri, isNull);
  });

  test('显式 saved + galleryUri', () {
    const r = CaptureResult(
      finalPath: 'Movies/GIFForge/capture_1.mp4',
      durationMs: 3200,
      galleryStatus: GallerySaveStatus.saved,
      galleryUri: 'content://media/external/video/media/7',
    );
    expect(r.galleryStatus, GallerySaveStatus.saved);
    expect(r.galleryUri, 'content://media/external/video/media/7');
  });

  test('failed 携带相册路径但状态失败(副本保留供手动处理)', () {
    const r = CaptureResult(
      finalPath: 'Movies/GIFForge/capture_1.mp4',
      durationMs: 1000,
      galleryStatus: GallerySaveStatus.failed,
    );
    expect(r.galleryStatus, GallerySaveStatus.failed);
    expect(r.finalPath, isNotEmpty);
  });
}

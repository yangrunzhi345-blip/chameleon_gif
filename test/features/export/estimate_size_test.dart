import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/export/application/estimate_size.dart';

/// [estimateGifSize] 估算契约(P4-WP2,面板预估展示)。
void main() {
  const video = VideoInfo(
    path: '/tmp/a.mp4',
    formatName: 'mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  test('固定输入:10s × 15fps × 默认原图等比(640×360)× 0.35', () {
    // 默认宽 0 = 原图等比:150 帧 × 230400 像素(640×360)× 0.35 ≈ 28MB
    final bytes = estimateGifSize(setting: const GifSetting(), video: video);
    expect(bytes, closeTo(150 * 640 * 360 * kGifCompressionFactor, 1));
  });

  test('width=480 显式指定 → 等比缩放 480×270', () {
    final bytes = estimateGifSize(
      setting: const GifSetting(width: 480),
      video: video,
    );
    // height = 360 * 480 / 640 = 270
    expect(bytes, closeTo(150 * 480 * 270 * kGifCompressionFactor, 1));
  });

  test('仅高度指定 → 宽度按源比例等比', () {
    final bytes = estimateGifSize(
      setting: const GifSetting(height: 270),
      video: video,
    );
    // width = 640 * 270 / 360 = 480
    expect(bytes, closeTo(150 * 480 * 270 * kGifCompressionFactor, 1));
  });

  test('宽高同时指定 → 直接用指定尺寸', () {
    final bytes = estimateGifSize(
      setting: const GifSetting(width: 480, height: 300),
      video: video,
    );
    expect(bytes, closeTo(150 * 480 * 300 * kGifCompressionFactor, 1));
  });

  test('裁剪窗口影响帧数', () {
    final a = estimateGifSize(setting: const GifSetting(), video: video);
    final b = estimateGifSize(
      setting: const GifSetting(
        start: Duration(seconds: 5),
        end: Duration(seconds: 6),
      ),
      video: video,
    );
    expect(b, lessThan(a), reason: '1s 窗口帧数远小于全片');
    expect(b, closeTo(a / 10, a / 10 * 0.1));
  });

  test('源宽未知 → 0(UI 显示 —)', () {
    const unknown = VideoInfo(
      path: '/tmp/a.mp4',
      formatName: 'mp4',
      duration: Duration(seconds: 10),
      width: 0,
      height: 0,
      fps: 30,
      codec: 'h264',
    );
    expect(estimateGifSize(setting: const GifSetting(), video: unknown), 0);
  });
}

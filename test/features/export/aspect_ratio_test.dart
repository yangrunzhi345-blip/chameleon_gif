import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/export/application/aspect_ratio.dart';

/// [isAspectRatioMatch] 纯函数单测(宽高比例一致性判断)。
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

  test('宽高都 0(原图)→ 一致', () {
    expect(isAspectRatioMatch(const GifSetting(), video), isTrue);
  });

  test('单边指定(等比)→ 一致', () {
    expect(isAspectRatioMatch(const GifSetting(width: 480), video), isTrue);
    expect(isAspectRatioMatch(const GifSetting(height: 270), video), isTrue);
  });

  test('双边指定且比例一致 → 一致', () {
    // 640:360 = 480:270
    expect(
      isAspectRatioMatch(const GifSetting(width: 480, height: 270), video),
      isTrue,
    );
  });

  test('双边指定且比例不一致 → 不一致(将变形)', () {
    // 640:360 ≠ 480:300
    expect(
      isAspectRatioMatch(const GifSetting(width: 480, height: 300), video),
      isFalse,
    );
    // 更极端:强制方形
    expect(
      isAspectRatioMatch(const GifSetting(width: 500, height: 500), video),
      isFalse,
    );
  });

  test('源尺寸未知 → 不提示(恒一致)', () {
    const unknown = VideoInfo(
      path: '/tmp/u.mp4',
      formatName: 'mp4',
      duration: Duration.zero,
      width: 0,
      height: 0,
      fps: null,
      codec: '',
    );
    expect(
      isAspectRatioMatch(const GifSetting(width: 480, height: 300), unknown),
      isTrue,
    );
  });
}

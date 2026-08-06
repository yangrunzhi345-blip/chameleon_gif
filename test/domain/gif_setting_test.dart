import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';

/// [GifSetting] 序列化契约(docs/14-测试计划.md §14.2 模型序列化)。
void main() {
  group('toJson/fromJson 往返', () {
    test('全字段设置往返一致', () {
      const s = GifSetting(
        fps: 24,
        width: 320,
        height: 270,
        start: Duration(seconds: 1),
        end: Duration(seconds: 5),
        loop: 2,
      );
      expect(GifSetting.fromJson(s.toJson()), s);
    });

    test('end=null 往返保持 null', () {
      const s = GifSetting();
      expect(s.end, isNull);
      expect(GifSetting.fromJson(s.toJson()).end, isNull);
    });
  });

  group('缺失字段默认值(老历史 JSON 兼容,§7.5)', () {
    test('空 JSON → 内置默认', () {
      final s = GifSetting.fromJson(const {});
      expect(s.fps, 15.0);
      expect(s.width, 0); // 默认原图等比
      expect(s.start, Duration.zero);
      expect(s.end, isNull);
      expect(s.loop, 0);
      // 图片模式字段:老 JSON 无此字段 → 默认
      expect(s.frameDurationMs, isNull);
      expect(s.usePalette, isTrue);
      // 缩放倍数:老 JSON 无此字段 → 默认 1.0(不缩放)
      expect(s.scaleMultiplier, 1.0);
      // 播放速度:老 JSON 无此字段 → 默认 1.0(正常速度)
      expect(s.playbackSpeed, 1.0);
    });

    test('老 JSON 无 scaleMultiplier 键 → 1.0;带键 → 原样往返', () {
      final legacy = GifSetting.fromJson(const {'fps': 24});
      expect(legacy.scaleMultiplier, 1.0);

      const scaled = GifSetting(scaleMultiplier: 2.0);
      final roundTrip = GifSetting.fromJson(scaled.toJson());
      expect(roundTrip.scaleMultiplier, 2.0);
      expect(roundTrip, scaled);
    });

    test('老 JSON 无 playbackSpeed 键 → 1.0;带键 → 原样往返', () {
      final legacy = GifSetting.fromJson(const {'fps': 24});
      expect(legacy.playbackSpeed, 1.0);

      const sped = GifSetting(playbackSpeed: 2.0);
      final roundTrip = GifSetting.fromJson(sped.toJson());
      expect(roundTrip.playbackSpeed, 2.0);
      expect(roundTrip, sped);
    });

    test('end 显式 null 容错', () {
      final s = GifSetting.fromJson(const {'end': null, 'fps': 30});
      expect(s.end, isNull);
      expect(s.fps, 30);
    });

    test('图片字段读写往返', () {
      const s = GifSetting(frameDurationMs: 500, usePalette: false);
      expect(GifSetting.fromJson(s.toJson()), s);
    });
  });

  group('effectiveFrameDuration', () {
    test('frameDurationMs 显式 → 原样返回', () {
      const s = GifSetting(frameDurationMs: 500);
      expect(s.effectiveFrameDuration, const Duration(milliseconds: 500));
    });

    test('frameDurationMs 为 null → 由 fps 推导(每图一帧)', () {
      const s = GifSetting(fps: 15);
      expect(s.effectiveFrameDuration, const Duration(milliseconds: 66));
      const s10 = GifSetting(fps: 10);
      expect(s10.effectiveFrameDuration, const Duration(milliseconds: 100));
    });

    test('下限保护:推导值至少 1ms', () {
      const s = GifSetting(fps: 60);
      expect(s.effectiveFrameDuration.inMilliseconds, greaterThanOrEqualTo(1));
    });
  });
}

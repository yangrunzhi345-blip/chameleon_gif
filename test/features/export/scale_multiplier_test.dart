import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/export/application/scale_multiplier.dart';
import 'package:flutter_test/flutter_test.dart';

/// 等比缩放倍数纯函数:尺寸换算 / 倍数匹配 / 提交展开。
void main() {
  group('scaledDimension:源尺寸 × 倍数 → 输出尺寸', () {
    test('整倍数精确换算', () {
      expect(scaledDimension(640, 2.0), 1280);
      expect(scaledDimension(640, 0.5), 320);
      expect(scaledDimension(640, 1.0), 640);
    });

    test('非整结果 round 后偶数化(FFmpeg 编码惯例)', () {
      // 853 × 0.5 = 426.5 → round 427 → 偶数化 426
      expect(scaledDimension(853, 0.5), 426);
      // 640 × 0.75 = 480
      expect(scaledDimension(640, 0.75), 480);
    });

    test('clamp 下限 2(0 尺寸防误展开)', () {
      expect(scaledDimension(3, 0.5), 2);
      expect(scaledDimension(1, 0.5), 2);
    });

    test('clamp 上限 4096(与表单宽高上限一致)', () {
      expect(scaledDimension(7000, 1.5), 4096);
    });
  });

  group('matchScaleMultiplier:宽高是否命中某选项倍数', () {
    test('2 倍命中', () {
      expect(
        matchScaleMultiplier(
          sourceWidth: 640,
          sourceHeight: 360,
          width: 1280,
          height: 720,
        ),
        2.0,
      );
    });

    test('0.75 倍命中(偶数化后比较)', () {
      expect(
        matchScaleMultiplier(
          sourceWidth: 640,
          sourceHeight: 360,
          width: 480,
          height: 270,
        ),
        0.75,
      );
    });

    test('手动宽高不匹配任何倍数 → null', () {
      expect(
        matchScaleMultiplier(
          sourceWidth: 640,
          sourceHeight: 360,
          width: 480,
          height: 300,
        ),
        isNull,
      );
    });

    test('宽高全 0(原图等比)或源尺寸未知 → null', () {
      expect(
        matchScaleMultiplier(
          sourceWidth: 640,
          sourceHeight: 360,
          width: 0,
          height: 0,
        ),
        isNull,
      );
      expect(
        matchScaleMultiplier(
          sourceWidth: 0,
          sourceHeight: 0,
          width: 640,
          height: 360,
        ),
        isNull,
      );
    });
  });

  group('expandScaleMultiplier:提交时展开', () {
    test('宽高全 0 且倍数非 1 → 按源尺寸落成具体宽高', () {
      final expanded = expandScaleMultiplier(
        const GifSetting(scaleMultiplier: 2.0),
        sourceWidth: 640,
        sourceHeight: 360,
      );
      expect(expanded.width, 1280);
      expect(expanded.height, 720);
    });

    test('倍数 1.0(不缩放)→ 原样返回', () {
      final setting = const GifSetting();
      expect(
        expandScaleMultiplier(setting, sourceWidth: 640, sourceHeight: 360),
        same(setting),
      );
    });

    test('宽高已显式指定 → 不展开(手动值优先)', () {
      final setting = const GifSetting(width: 480, scaleMultiplier: 2.0);
      expect(
        expandScaleMultiplier(setting, sourceWidth: 640, sourceHeight: 360),
        same(setting),
      );
    });

    test('源尺寸未知(≤0)→ 原样返回(防 0 尺寸误展开)', () {
      final setting = const GifSetting(scaleMultiplier: 2.0);
      expect(
        expandScaleMultiplier(setting, sourceWidth: 0, sourceHeight: 0),
        same(setting),
      );
    });

    test('JSON 浮点噪声:2.0000000001 视为非 1 → 展开', () {
      final expanded = expandScaleMultiplier(
        const GifSetting(scaleMultiplier: 2.0000000001),
        sourceWidth: 640,
        sourceHeight: 360,
      );
      expect(expanded.width, 1280);
    });
  });
}

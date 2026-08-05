import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/per_image_control.dart';

/// [PerImageControl] 契约(精细控制参数:默认判定 / JSON 往返 / 摘要文案)。
void main() {
  group('isDefault', () {
    test('默认构造 → 未操作', () {
      expect(const PerImageControl().isDefault, isTrue);
    });

    test('倍率非 1 → 已操作', () {
      expect(const PerImageControl(scaleMultiplier: 2.0).isDefault, isFalse);
    });

    test('宽或高非 0 → 已操作', () {
      expect(const PerImageControl(width: 480).isDefault, isFalse);
      expect(const PerImageControl(height: 480).isDefault, isFalse);
    });

    test('浮点噪声容错:1.0000001 → 默认', () {
      expect(
        const PerImageControl(scaleMultiplier: 1.0000001).isDefault,
        isTrue,
      );
    });
  });

  group('JSON 往返', () {
    test('全字段往返一致', () {
      const c = PerImageControl(scaleMultiplier: 2.0, width: 480, height: 360);
      expect(PerImageControl.fromJson(c.toJson()), c);
    });

    test('默认对象往返 → 默认', () {
      const c = PerImageControl();
      expect(PerImageControl.fromJson(c.toJson()).isDefault, isTrue);
    });

    test('缺失字段 → 默认值(老 JSON 兼容)', () {
      final c = PerImageControl.fromJson(const {});
      expect(c.scaleMultiplier, 1.0);
      expect(c.width, 0);
      expect(c.height, 0);
      expect(c.isDefault, isTrue);
    });
  });

  group('summary(UI 信息文本)', () {
    test('默认 → 空串(不显示)', () {
      expect(const PerImageControl().summary, isEmpty);
    });

    test('仅倍率', () {
      expect(const PerImageControl(scaleMultiplier: 2.0).summary, '缩放倍率:2');
    });

    test('仅宽高', () {
      expect(
        const PerImageControl(width: 480, height: 360).summary,
        '宽度:480 高度:360',
      );
    });

    test('三者全有(整倍数不带小数点)', () {
      expect(
        const PerImageControl(
          scaleMultiplier: 2.0,
          width: 480,
          height: 360,
        ).summary,
        '缩放倍率:2 宽度:480 高度:360',
      );
    });

    test('非整数倍率原样显示', () {
      expect(const PerImageControl(scaleMultiplier: 1.5).summary, '缩放倍率:1.5');
    });
  });
}

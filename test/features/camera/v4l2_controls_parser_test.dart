import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/features/camera/application/v4l2_controls_parser.dart';

/// v4l2-ctl -L 控制项输出解析(夹具为本机真实输出固化)。
void main() {
  group('本机夹具(controls.txt)', () {
    late List<CameraControlCapability> controls;

    setUpAll(() {
      final raw = File('test/fixtures/v4l2/controls.txt').readAsStringSync();
      controls = parseV4l2Controls(raw);
    });

    test('int 型:min/max/step/default/value 完整解析', () {
      final brightness = controls.firstWhere((c) => c.id == 'brightness');
      expect(brightness.kind, CameraControlKind.int);
      expect(brightness.min, -64);
      expect(brightness.max, 64);
      expect(brightness.step, 1);
      expect(brightness.defaultValue, 0);
      expect(brightness.value, 0);
      expect(brightness.active, isTrue);
    });

    test('bool 型:无 min/max,value 为 0/1', () {
      final wb = controls.firstWhere((c) => c.id == 'white_balance_automatic');
      expect(wb.kind, CameraControlKind.bool);
      expect(wb.min, isNull);
      expect(wb.value, 1);
      expect(wb.active, isTrue);
    });

    test('menu 型:完整选项映射 + 当前值标签', () {
      final plf = controls.firstWhere((c) => c.id == 'power_line_frequency');
      expect(plf.kind, CameraControlKind.menu);
      expect(plf.choices, {0: 'Disabled', 1: '50 Hz', 2: '60 Hz'});
      expect(plf.value, 2);
    });

    test('inactive 标记:自动白平衡开启时色温项不活跃', () {
      final wbTemp = controls.firstWhere(
        (c) => c.id == 'white_balance_temperature',
      );
      expect(wbTemp.active, isFalse);
      expect(wbTemp.min, 2800);
      expect(wbTemp.max, 6500);
      expect(wbTemp.step, 10);
    });

    test('rect/bitmask 等不支持类型被跳过', () {
      expect(controls.any((c) => c.id.contains('region_of_interest')), isFalse);
      // 支持项 13 = User 10(brightness/contrast/saturation/hue/
      // white_balance_automatic/gamma/power_line_frequency/
      // white_balance_temperature/sharpness/backlight_compensation)
      // + Camera 3(auto_exposure/exposure_time_absolute/
      // exposure_dynamic_framerate);rect/bitmask 2 项被跳过
      expect(controls, hasLength(13));
      expect(
        controls.map((c) => c.id).toSet(),
        containsAll({
          'auto_exposure',
          'exposure_time_absolute',
          'exposure_dynamic_framerate',
        }),
      );
    });
  });

  test('空输出 → 空列表', () {
    expect(parseV4l2Controls(''), isEmpty);
  });

  test('无类型行/杂项不误解析', () {
    const raw =
        'some random line\n\n  brightness 0x00980900 (int) : min=-1 max=1\n';
    final controls = parseV4l2Controls(raw);
    expect(controls, hasLength(1));
    expect(controls.single.id, 'brightness');
    expect(controls.single.min, -1);
    expect(controls.single.max, 1);
    expect(controls.single.defaultValue, isNull);
  });
}

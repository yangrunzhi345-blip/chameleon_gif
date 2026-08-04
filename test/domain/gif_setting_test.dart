import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';

/// [GifSetting] 序列化契约(docs/14-测试计划.md §14.2 模型序列化)。
void main() {
  group('toJson/fromJson 往返', () {
    test('全字段设置往返一致', () {
      const s = GifSetting(
        fps: 24,
        width: 320,
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
      expect(s.width, 480);
      expect(s.start, Duration.zero);
      expect(s.end, isNull);
      expect(s.loop, 0);
    });

    test('end 显式 null 容错', () {
      final s = GifSetting.fromJson(const {'end': null, 'fps': 30});
      expect(s.end, isNull);
      expect(s.fps, 30);
    });
  });
}

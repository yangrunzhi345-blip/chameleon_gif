import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';

/// [RecordParams] 默认值、copyWith 与 JSON 往返(docs/19 §3.1)。
void main() {
  test('默认值全量断言', () {
    const p = RecordParams();
    expect(p.fps, 15.0);
    expect(p.maxDurationMs, 0, reason: '默认不限时长');
    expect(p.regionMode, RecordRegion.fullscreen);
    expect(p.windowTitle, isNull);
    expect(p.regionX, isNull);
    expect(p.regionY, isNull);
    expect(p.regionWidth, isNull);
    expect(p.regionHeight, isNull);
    expect(p.drawCursor, isTrue);
    expect(p.aspectRatio, isNull);
    expect(p.outputDir, isNull);
  });

  test('copyWith 局部修改保留其余字段', () {
    const p = RecordParams();
    final q = p.copyWith(fps: 30, regionMode: RecordRegion.window);
    expect(q.fps, 30);
    expect(q.regionMode, RecordRegion.window);
    expect(q.maxDurationMs, 0, reason: '未改字段保留默认(不限)');
    expect(q.drawCursor, isTrue);
  });

  test('JSON 往返(含枚举与区域 int 原语)', () {
    const p = RecordParams(
      fps: 10,
      maxDurationMs: 30000,
      regionMode: RecordRegion.custom,
      regionX: 100,
      regionY: 50,
      regionWidth: 1280,
      regionHeight: 720,
      drawCursor: false,
      aspectRatio: 16 / 9,
    );
    final json = p.toJson();
    final restored = RecordParams.fromJson(json);
    expect(restored, p);
    // 枚举序列化名与 int 原语字段
    expect(json['regionMode'], 'custom');
    expect(json['regionX'], 100);
    expect(json['regionWidth'], 1280);
    expect(json['drawCursor'], isFalse);
    expect(json['aspectRatio'], closeTo(16 / 9, 1e-9));
  });

  test('老 JSON 兼容:缺字段读默认值', () {
    final restored = RecordParams.fromJson(const {'fps': 5});
    expect(restored.fps, 5);
    expect(restored.maxDurationMs, 0, reason: '老 JSON 缺字段读默认(不限)');
    expect(restored.regionMode, RecordRegion.fullscreen);
  });
}

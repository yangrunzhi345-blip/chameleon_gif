import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';

/// [CaptureParams] 默认值、copyWith 与 JSON 往返(docs/18 §5.1)。
void main() {
  test('默认值全量断言', () {
    const p = CaptureParams();
    expect(p.fps, 15.0);
    expect(p.resolutionWidth, isNull);
    expect(p.resolutionHeight, isNull);
    expect(p.maxDurationMs, 30000);
    expect(p.whiteBalanceTemp, isNull);
    expect(p.whiteBalanceAuto, isTrue);
    expect(p.exposureCompensation, isNull);
    expect(p.exposureLock, isFalse);
    expect(p.iso, isNull);
    expect(p.focusMode, FocusMode.auto);
    expect(p.zoom, isNull);
    expect(p.flashOn, isFalse);
    expect(p.outputDir, isNull);
  });

  test('copyWith 局部修改保留其余字段', () {
    const p = CaptureParams();
    final q = p.copyWith(fps: 30, flashOn: true);
    expect(q.fps, 30);
    expect(q.flashOn, isTrue);
    expect(q.maxDurationMs, 30000); // 未改字段保留默认
    expect(q.focusMode, FocusMode.auto);
  });

  test('JSON 往返(含枚举与可空字段)', () {
    const p = CaptureParams(
      fps: 24,
      maxDurationMs: 10000,
      focusMode: FocusMode.manual,
      iso: 200,
      outputDir: '/tmp/captures',
    );
    final json = p.toJson();
    final restored = CaptureParams.fromJson(json);
    expect(restored, p);
    // 枚举序列化名与可空字段键
    expect(json['focusMode'], 'manual');
    expect(json['iso'], 200);
    expect(json['outputDir'], '/tmp/captures');
    expect(json.containsKey('whiteBalanceTemp'), isTrue);
    expect(json['whiteBalanceTemp'], isNull);
  });

  test('老 JSON 兼容:缺字段读默认值', () {
    final restored = CaptureParams.fromJson(const {'fps': 10});
    expect(restored.fps, 10);
    expect(restored.maxDurationMs, 30000);
    expect(restored.focusMode, FocusMode.auto);
  });
}

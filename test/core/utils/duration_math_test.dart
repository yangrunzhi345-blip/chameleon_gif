import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/utils/duration_math.dart';

/// [normalizeRange] 自动交换契约(P4 阶段门,docs/12 §12.3)。
void main() {
  test('起点 > 终点 → 自动交换', () {
    final (s, e) = normalizeRange(
      const Duration(seconds: 9),
      const Duration(seconds: 3),
    );
    expect(s, const Duration(seconds: 3));
    expect(e, const Duration(seconds: 9));
  });

  test('起点 < 终点 → 保持原序', () {
    final (s, e) = normalizeRange(
      const Duration(seconds: 3),
      const Duration(seconds: 9),
    );
    expect(s, const Duration(seconds: 3));
    expect(e, const Duration(seconds: 9));
  });

  test('相等时不交换(拒绝语义由调用方决定)', () {
    final (s, e) = normalizeRange(
      const Duration(seconds: 5),
      const Duration(seconds: 5),
    );
    expect(s, const Duration(seconds: 5));
    expect(e, const Duration(seconds: 5));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/converter/application/image_segmentation.dart';

/// 分段策略与进度聚合器测试(纯 Dart,2026-08-07 大图闪退修复)。
void main() {
  group('segmentSizes', () {
    test('N ≤ 阈值 → 单段', () {
      expect(segmentSizes(20), [20]);
      expect(segmentSizes(5), [5]);
    });

    test('21 → 均分两段 [11, 10]', () {
      expect(segmentSizes(21), [11, 10]);
    });

    test('41 → 三段均分 [14, 14, 13]', () {
      expect(segmentSizes(41), [14, 14, 13]);
    });

    test('100 → 五段 [20×5],每段 ≤ 20', () {
      expect(segmentSizes(100), [20, 20, 20, 20, 20]);
    });

    test('属性:和 = 图片数,每段 ≤ maxSegment', () {
      for (final n in [21, 22, 39, 40, 41, 67, 100, 101]) {
        final sizes = segmentSizes(n);
        expect(sizes.fold<int>(0, (a, b) => a + b), n);
        expect(sizes.every((s) => s <= kMaxSegmentImages), isTrue);
        expect(sizes.every((s) => s >= 1), isTrue);
      }
    });
  });

  group('SegmentedProgressAggregator(调色板,100 张,每图 2 帧)', () {
    const agg = SegmentedProgressAggregator(
      segmentSizes: [20, 20, 20, 20, 20],
      framesPerImage: 2,
      usePalette: true,
    );

    test('totalFrames = 200,totalWork = 3', () {
      expect(agg.totalFrames, 200);
      expect(agg.totalWork, 3);
    });

    test('段 0:起点 0,intra=0.5 → 中值,intra=1 → 40/600', () {
      expect(agg.segmentOverall(0, 0), closeTo(0, 1e-9));
      expect(agg.segmentOverall(0, 0.5), closeTo(20 / 600, 1e-9));
      expect(agg.segmentOverall(0, 1), closeTo(40 / 600, 1e-9));
    });

    test('段末(段 4 intra=1)恰为冻结位 1/3', () {
      expect(agg.segmentOverall(4, 1), closeTo(1 / 3, 1e-9));
      expect(agg.paletteGenFrozen(), closeTo(1 / 3, 1e-9));
    });

    test('段间连续:段 0 末 == 段 1 起点', () {
      expect(agg.segmentOverall(0, 1), agg.segmentOverall(1, 0));
    });

    test('encode:起点 = 冻结位(无跳变),终点 = 100%', () {
      expect(agg.encodeOverall(0), closeTo(1 / 3, 1e-9));
      expect(agg.encodeOverall(1), closeTo(1.0, 1e-9));
      expect(agg.encodeOverall(0.5), closeTo(2 / 3, 1e-9));
    });

    test('全程单调(段 → 冻结 → encode 采样序列)', () {
      var prev = 0.0;
      for (final v in [
        agg.segmentOverall(0, 0.5),
        agg.segmentOverall(0, 1),
        agg.segmentOverall(1, 0.5),
        agg.segmentOverall(4, 1),
        agg.paletteGenFrozen(),
        agg.encodeOverall(0.2),
        agg.encodeOverall(0.9),
        agg.encodeOverall(1),
      ]) {
        expect(v, greaterThanOrEqualTo(prev), reason: '进度必须单调不回落');
        prev = v;
      }
    });

    test('intra 越界钳制(负数 / >1)', () {
      expect(agg.segmentOverall(0, -1), agg.segmentOverall(0, 0));
      expect(agg.encodeOverall(2), agg.encodeOverall(1));
    });
  });

  group('SegmentedProgressAggregator(单遍,21 张,每图 2 帧)', () {
    const agg = SegmentedProgressAggregator(
      segmentSizes: [11, 10],
      framesPerImage: 2,
      usePalette: false,
    );

    test('totalWork = 2,段末 = 1/2,encode 0→1.0', () {
      expect(agg.totalWork, 2);
      expect(agg.segmentOverall(1, 1), closeTo(0.5, 1e-9));
      expect(agg.paletteGenFrozen(), closeTo(0.5, 1e-9));
      expect(agg.encodeOverall(0), closeTo(0.5, 1e-9));
      expect(agg.encodeOverall(1), closeTo(1.0, 1e-9));
    });

    test('段 0 末 == 段 1 起点(帧权均分连续)', () {
      expect(agg.segmentOverall(0, 1), agg.segmentOverall(1, 0));
    });
  });
}

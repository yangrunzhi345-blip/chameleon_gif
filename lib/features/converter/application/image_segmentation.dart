/// 大图集合分段策略(图片模式 N>20 时启用)。
///
/// 背景:ffmpeg 为每张图片开一个 `-loop 1` 输入,concat 各持一帧,
/// 2048×2048 RGBA 16MB/帧 → 100 张稳态原生 RSS 2-4GB → lmkd/OOM
/// 杀进程闪退(Android 真机 2026-08-07 实证:20 张通过 / 100 张闪退)。
/// 分段路径:每段 ≤ [kMaxSegmentImages] 张编码为 ffv1 无损 mkv 中间片
/// (段内峰值与单次运行一致),concat 后统一调色板输出,质量与单次
/// 运行完全一致。
library;

/// 分段模式阈值:图片数超过该值走分段转换(≤20 张实测内存安全)。
const int kSegmentModeThreshold = 20;

/// 单段最大图片数(20 张真机实测通过;段内 ~640MB 原生 RSS)。
const int kMaxSegmentImages = 20;

/// 图片总数 → 每段图片数列表(段间尽量均分:余数分发到前 rem 段)。
///
/// 契约:元素和 = [imageCount];每段 ≤ [maxSegment];≥1。
/// 例:21 → [11, 10];41 → [14, 14, 13];100 → [20×5]。
List<int> segmentSizes(int imageCount, {int maxSegment = kMaxSegmentImages}) {
  assert(imageCount > 0, '图片数须 ≥1');
  final k = (imageCount / maxSegment).ceil();
  final base = imageCount ~/ k;
  final rem = imageCount % k;
  return [for (var i = 0; i < k; i++) base + (i < rem ? 1 : 0)];
}

/// 分段进度聚合器(纯函数,可单测)。
///
/// 统一以"帧权"折算总体进度,totalWork = 3(调色板:段编码 1 遍 +
/// palettegen 1 遍 + encode 1 遍)或 2(单遍:段 + encode):
/// - 段 k 阶段(intra = 段内百分比):`(Σ_{j<k} segFrames(j) +
///   segFrames(k)×intra) / totalFrames / totalWork`;全段完成 → 1/totalWork
/// - palettegen 阶段:**忽略 intra,冻结在 1/totalWork**(= 1/3 或 1/2)
///   ——两端一致:桌面无 progress 行自然冻结,Android statistics 合成行
///   被本聚合器丢弃,不产生跳变
/// - encode 阶段(intra = 输出时间轴百分比):`(1 + (totalWork-1)×intra)
///   / totalWork`——覆盖 [1/totalWork, 1.0],palettegen 的工作量并入
///   encode 区间显示,全程单调、终点恰为 100%
///
/// 进度曲线(调色板):0 → 33%(段)→ 33% 冻结(palettegen)→ 33% → 100%
/// (encode);palettegen 期间停留 = 阶段文案兜底,无跳变。
class SegmentedProgressAggregator {
  const SegmentedProgressAggregator({
    required this.segmentSizes,
    required this.framesPerImage,
    required this.usePalette,
  });

  /// 每段图片数(与 [segmentSizes] 产出一致)。
  final List<int> segmentSizes;

  /// 每图帧数(整帧量化:`quantizedFrameDuration × fps`,整数;
  /// double 防御非整边界)。
  final double framesPerImage;

  /// 是否调色板两遍(决定 totalWork 与冻结位)。
  final bool usePalette;

  /// 总帧权 = 图片数 × 每图帧数。
  double get totalFrames =>
      segmentSizes.fold<int>(0, (a, b) => a + b) * framesPerImage;

  /// 总遍数(段编码 + palettegen + encode / 段编码 + encode)。
  double get totalWork => usePalette ? 3.0 : 2.0;

  /// 前 [k] 段累计帧权(不含第 k 段)。
  double completedFramesBefore(int k) {
    var acc = 0.0;
    for (var j = 0; j < k && j < segmentSizes.length; j++) {
      acc += segmentSizes[j] * framesPerImage;
    }
    return acc;
  }

  /// 段 [k] 阶段总体进度([intra] ∈ [0,1] 段内百分比)。
  double segmentOverall(int k, double intra) {
    final segFrames = segmentSizes[k] * framesPerImage;
    return (completedFramesBefore(k) + segFrames * intra.clamp(0.0, 1.0)) /
        totalFrames /
        totalWork;
  }

  /// palettegen 阶段冻结进度(忽略段内进展,防两端进度表现不一致)。
  double paletteGenFrozen() => 1.0 / totalWork;

  /// encode 阶段总体进度([intra] ∈ [0,1] 输出时间轴百分比)。
  ///
  /// 覆盖 [1/totalWork, 1.0]:段完成位起,终点恰为 100%;
  /// palettegen 的工作量并入本区间显示(阶段切换无跳变)。
  double encodeOverall(double intra) {
    return (1.0 + (totalWork - 1.0) * intra.clamp(0.0, 1.0)) / totalWork;
  }
}

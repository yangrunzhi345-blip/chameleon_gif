import '../../../domain/value_objects/gif_setting.dart';

/// 等比缩放倍数选项(1.0 = 不缩放,默认;含 0.1–0.4 精细缩小档)。
const kScaleMultiplierOptions = [
  0.1,
  0.2,
  0.3,
  0.4,
  0.5,
  0.75,
  1.0,
  1.5,
  2.0,
  3.0,
];

/// 源尺寸 × 倍数 → 输出尺寸。
///
/// round 取整后偶数化(FFmpeg 编码惯例,避免奇数宽高兼容问题),
/// 再 clamp 到 [2, 4096](与表单宽高上限一致)。
int scaledDimension(int source, double multiplier) {
  var v = (source * multiplier).round();
  if (v.isOdd) v -= 1;
  return v.clamp(2, 4096);
}

/// 当前宽高是否精确等于某选项倍数(经 [scaledDimension] 归一后比较)。
///
/// 命中返回该倍数,否则 null。宽高为 (0, 0)(原图等比)返回 null,
/// 该情形由各控制器按页面语义特判(预览页 → 1.0,设置页 → 保持存储值)。
double? matchScaleMultiplier({
  required int sourceWidth,
  required int sourceHeight,
  required int width,
  required int height,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) return null;
  if (width == 0 && height == 0) return null;
  for (final m in kScaleMultiplierOptions) {
    if (scaledDimension(sourceWidth, m) == width &&
        scaledDimension(sourceHeight, m) == height) {
      return m;
    }
  }
  return null;
}

/// 提交时展开:width==height==0 且倍数非 1.0 → 按源尺寸落成具体宽高。
///
/// 源尺寸 ≤ 0(未知)、倍数为 1.0(不缩放)或宽高已显式指定时原样返回。
/// 使任务参数自包含(历史重转/崩溃恢复语义一致),命令构造零改动。
GifSetting expandScaleMultiplier(
  GifSetting setting, {
  required int sourceWidth,
  required int sourceHeight,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) return setting;
  if (setting.width != 0 || setting.height != 0) return setting;
  final m = setting.scaleMultiplier;
  // JSON 解析浮点噪声防护:非 1.0 判断用 epsilon。
  if ((m - 1.0).abs() <= 1e-9) return setting;
  return setting.copyWith(
    width: scaledDimension(sourceWidth, m),
    height: scaledDimension(sourceHeight, m),
  );
}

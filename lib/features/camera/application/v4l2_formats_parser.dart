/// v4l2-ctl --list-formats-ext 输出解析(纯函数,可单测;本机真实
/// 输出固化为夹具)。
///
/// 输出形态(实测):
/// ```
/// 	[0]: 'MJPG' (Motion-JPEG, compressed)
/// 		Size: Discrete 1280x720
/// 			Interval: Discrete 0.033s (30.000 fps)
/// ```
/// 仅收集 Discrete 尺寸与 Discrete 帧率(Stepwise/Continuous 跳过,
/// 不可作固定参数)。JPEG 压缩流(MJPG)与原始流(YUYV)并存时,
/// 调用方按 [V4l2FormatEntry.format] 优先 MJPG。
library;

/// 单格式单尺寸条目。
class V4l2FormatEntry {
  const V4l2FormatEntry({
    required this.format,
    required this.width,
    required this.height,
    required this.frameRates,
  });

  /// 像素格式名('MJPG' / 'YUYV')。
  final String format;

  final int width;
  final int height;

  /// 该尺寸支持的帧率列表(Interval 解析,降序按出现顺序)。
  final List<double> frameRates;
}

/// 解析 `--list-formats-ext` 输出 → 尺寸/帧率条目列表。
List<V4l2FormatEntry> parseV4l2FormatsExt(String output) {
  final entries = <V4l2FormatEntry>[];
  final formatPattern = RegExp(r"\[\d+\]: '([A-Z0-9_]+)'");
  final sizePattern = RegExp(r'Size: Discrete (\d+)x(\d+)');
  final intervalPattern = RegExp(r'Interval: Discrete .*\(([\d.]+) fps\)');

  String? currentFormat;
  int? sizeWidth;
  int? sizeHeight;
  final rates = <double>[];

  void flush() {
    // 闭包内对 sizeWidth/sizeHeight 赋值会阻断类型提升,先读入局部
    final w = sizeWidth;
    final h = sizeHeight;
    if (currentFormat != null && w != null && h != null && rates.isNotEmpty) {
      entries.add(
        V4l2FormatEntry(
          format: currentFormat,
          width: w,
          height: h,
          frameRates: List.unmodifiable(rates),
        ),
      );
    }
    sizeWidth = null;
    sizeHeight = null;
    rates.clear();
  }

  for (final line in output.split('\n')) {
    final formatMatch = formatPattern.firstMatch(line);
    if (formatMatch != null) {
      flush();
      currentFormat = formatMatch.group(1)!;
      continue;
    }
    final sizeMatch = sizePattern.firstMatch(line);
    if (sizeMatch != null) {
      flush();
      sizeWidth = int.parse(sizeMatch.group(1)!);
      sizeHeight = int.parse(sizeMatch.group(2)!);
      continue;
    }
    final intervalMatch = intervalPattern.firstMatch(line);
    if (intervalMatch != null) {
      rates.add(double.parse(intervalMatch.group(1)!));
    }
  }
  flush();
  return entries;
}

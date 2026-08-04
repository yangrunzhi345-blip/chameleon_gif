/// 单条 FFmpeg 命令模型(纯数据,见 docs/08-FFmpeg设计.md §8.3.2)。
///
/// [args] 为完整参数列表(不含可执行名,引擎按平台前缀 `ffmpeg` 执行);
/// [label] 标记命令阶段,供 UI 展示与日志定位。
class GifCommand {
  const GifCommand({required this.args, required this.label});

  /// 参数列表,顺序即命令顺序(快照单测断言契约)。
  final List<String> args;

  /// 阶段标签:'palette'(调色板第一遍)| 'encode'(编码第二遍/标准单遍)。
  final String label;

  static const kPaletteLabel = 'palette';
  static const kEncodeLabel = 'encode';
}

import '../value_objects/gif_setting.dart';

/// 图片→GIF 的源输入(多张图片按顺序合成帧动画)。
///
/// 与视频路径的 [VideoInfo] 平行:视频由 ffprobe 解析元数据,
/// 图片序列无时长信息,时长由 `GifSetting.effectiveFrameDuration × N` 推算。
/// width/height 为首图尺寸(0 = 未知,仅 UI 展示用,转换无需探测)。
class ImageGifSource {
  const ImageGifSource({required this.paths, this.width = 0, this.height = 0});

  /// 有序图片路径列表(≥1,顺序即播放顺序)
  final List<String> paths;

  /// 首图宽度(0 = 未知)
  final int width;

  /// 首图高度(0 = 未知)
  final int height;

  /// 总输出时长 = 每图时长 × 图片数(供进度分母/历史快照使用)。
  Duration totalDuration(GifSetting setting) {
    return Duration(
      microseconds:
          setting.effectiveFrameDuration.inMicroseconds * paths.length,
    );
  }
}

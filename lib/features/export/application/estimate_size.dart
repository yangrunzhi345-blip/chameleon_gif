import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';

/// GIF 输出大小估算系数(LZW 压缩经验值,粗略;仅用于面板预估展示)。
const kGifCompressionFactor = 0.35;

/// 预估输出 GIF 字节数(docs/10 §10.2.1"预估大小")。
///
/// 帧数 × 输出像素 × 每像素字节(8 位调色板 = 1B)× 压缩系数;
/// `width=0`(原图等比)取源宽;源宽未知时结果 0(UI 显示"—")。
int estimateGifSize({required GifSetting setting, required VideoInfo video}) {
  final width = setting.width > 0 ? setting.width : video.width;
  if (width <= 0 || video.height <= 0) return 0;
  final height = (video.height * width / video.width).round();
  final end = setting.end ?? video.duration;
  final seconds = (end - setting.start).inMilliseconds / 1000.0;
  final frames = setting.fps * seconds;
  return (frames * width * height * kGifCompressionFactor).round();
}

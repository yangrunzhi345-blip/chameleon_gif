import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';

/// GIF 输出大小估算系数(LZW 压缩经验值,粗略;仅用于面板预估展示)。
const kGifCompressionFactor = 0.35;

/// 体积提醒阈值:预估输出超过 50MB 时在面板提醒(不阻塞导出)。
const kGifSizeWarningBytes = 50 * 1024 * 1024;

/// 预估输出 GIF 字节数(docs/10 §10.2.1"预估大小")。
///
/// 帧数 × 输出像素 × 每像素字节(8 位调色板 = 1B)× 压缩系数。
/// 尺寸语义:宽高都 0(原图)取源尺寸;单边指定按源比例算另一边;
/// 双边指定直接用指定值。源尺寸未知时结果 0(UI 显示"—")。
int estimateGifSize({required GifSetting setting, required VideoInfo video}) {
  if (video.width <= 0 || video.height <= 0) return 0;
  // 输出尺寸:宽高独立指定用指定值;仅一边指定按源比例推另一边;
  // 都 0 = 源尺寸
  final width = setting.width > 0
      ? setting.width
      : setting.height > 0
      ? (video.width * setting.height / video.height).round()
      : video.width;
  final height = setting.height > 0
      ? setting.height
      : (video.height * width / video.width).round();
  final end = setting.end ?? video.duration;
  final seconds = (end - setting.start).inMilliseconds / 1000.0;
  final frames = setting.fps * seconds;
  return (frames * width * height * kGifCompressionFactor).round();
}

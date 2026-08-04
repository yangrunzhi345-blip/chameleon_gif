import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';

/// 输出宽高与源视频比例一致性判断(纯函数,面板警告展示用)。
///
/// 语义:宽高**同时指定**时,若比例与源视频不一致,输出将按指定尺寸
/// 精确缩放(scale=W:H),画面会被拉伸/压扁;面板据此提示后果但不阻塞
/// 导出(用户确认后可继续)。单边指定(另一边 -1 等比)或原图恒一致。
///
/// 交叉相乘整数比较(`width * video.height == height * video.width`)
/// 避免浮点误差。
bool isAspectRatioMatch(GifSetting setting, VideoInfo video) {
  if (setting.width <= 0 || setting.height <= 0) return true;
  if (video.width <= 0 || video.height <= 0) return true; // 源尺寸未知不提示
  return setting.width * video.height == setting.height * video.width;
}

/// 输出宽高比(预览"所见即所得"用,preview_screen 组装)。
///
/// 宽高同时指定 → 设置比例(预览画面按输出形状显示,含拉伸效果);
/// 单边指定或原图 → 源视频比例。源尺寸未知时按 16:9 兜底。
double outputAspectRatio(GifSetting setting, VideoInfo video) {
  if (setting.width > 0 && setting.height > 0) {
    return setting.width / setting.height;
  }
  final srcW = video.width > 0 ? video.width : 16;
  final srcH = video.height > 0 ? video.height : 9;
  return srcW / srcH;
}

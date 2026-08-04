import 'package:ffmpeg_kit_flutter_minimal/media_information.dart';

import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/source_broken_exception.dart';

/// ffprobe `MediaInformation` → [VideoInfo](纯函数,可单测)。
///
/// import ffmpeg_kit 包仅使用其数据模型类型(纯 Dart Map 包装,不含平台
/// 通道调用),不触 material/widgets,符合功能层红线。
class FfprobeVideoInfoParser {
  const FfprobeVideoInfoParser();

  /// 帧率分数求值:"30000/1001" → 29.97(3 位小数);
  /// "25/1" → 25.0;纯数字 "29.97" 兜底;0/0、分母为 0 或非法 → null。
  static double? frameRateFromFraction(String? fraction) {
    if (fraction == null || fraction.isEmpty) return null;
    final parts = fraction.split('/');
    if (parts.length == 1) return double.tryParse(parts[0].trim());
    final numerator = double.tryParse(parts[0].trim());
    final denominator = double.tryParse(parts[1].trim());
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return (numerator / denominator * 1000).roundToDouble() / 1000;
  }

  /// 解析 ffprobe 探测结果;成功探测但内容不可用(缺时长/无视频流/缺分辨率)
  /// 抛 [SourceBrokenException](错误码 `GIF_PROBE_NO_*`)。
  VideoInfo parse(MediaInformation mediaInfo, {required String path}) {
    // 此 fork 的 MediaInformation 原样透传 ffprobe JSON,format.duration 为秒字符串
    final durationSec = double.tryParse(mediaInfo.getDuration() ?? '');
    if (durationSec == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_DURATION');
    }
    final streams = mediaInfo.getStreams();
    final video = streams.where((s) => s.getType() == 'video').firstOrNull;
    if (video == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_VIDEO_STREAM');
    }
    final width = video.getWidth();
    final height = video.getHeight();
    if (width == null || height == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_RESOLUTION');
    }
    // 回退链:avg_frame_rate → r_frame_rate;全缺(如 0/0)为 null
    final fps =
        frameRateFromFraction(video.getAverageFrameRate()) ??
        frameRateFromFraction(video.getRealFrameRate());
    return VideoInfo(
      path: path,
      formatName: mediaInfo.getFormat() ?? 'unknown',
      duration: Duration(milliseconds: (durationSec * 1000).round()),
      width: width,
      height: height,
      fps: fps,
      codec: video.getCodec() ?? 'unknown',
    );
  }
}

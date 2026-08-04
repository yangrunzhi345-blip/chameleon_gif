import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/source_broken_exception.dart';

/// ffprobe JSON → [VideoInfo](纯函数,可单测)。
///
/// 消费 ffprobe 原始 JSON(`-show_format -show_streams` 输出),不依赖
/// ffmpeg_kit 类型(domain/infrastructure 零平台包依赖,见 docs/04 §4.2)。
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
  VideoInfo parseJson(Map<String, dynamic> probeJson, {required String path}) {
    final format = probeJson['format'];
    final durationSec = format is Map
        ? double.tryParse('${format['duration'] ?? ''}')
        : null;
    if (durationSec == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_DURATION');
    }
    final streams = probeJson['streams'];
    final video = streams is List
        ? streams
              .whereType<Map>()
              .where((s) => s['codec_type'] == 'video')
              .firstOrNull
        : null;
    if (video == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_VIDEO_STREAM');
    }
    final width = video['width'] as int?;
    final height = video['height'] as int?;
    if (width == null || height == null) {
      throw SourceBrokenException(errorCode: 'GIF_PROBE_NO_RESOLUTION');
    }
    // 回退链:avg_frame_rate → r_frame_rate;全缺(如 0/0)为 null
    final fps =
        frameRateFromFraction('${video['avg_frame_rate'] ?? ''}') ??
        frameRateFromFraction('${video['r_frame_rate'] ?? ''}');
    return VideoInfo(
      path: path,
      formatName: format is Map
          ? '${format['format_name'] ?? 'unknown'}'
          : 'unknown',
      duration: Duration(milliseconds: (durationSec * 1000).round()),
      width: width,
      height: height,
      fps: fps,
      codec: '${video['codec_name'] ?? 'unknown'}',
    );
  }
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_info.freezed.dart';
part 'video_info.g.dart';

/// 视频元数据(ffprobe 解析结果,见 docs/12-开发计划.md P1-WP2)。
///
/// 字段契约:path 为源文件绝对路径;formatName/codec 原样透传 ffprobe;
/// fps 为源帧率(avg_frame_rate 分数求值,未知为 null,下游用默认值);
/// duration 以微秒序列化(与 GifSetting 的 Duration 约定一致)。
@freezed
abstract class VideoInfo with _$VideoInfo {
  const factory VideoInfo({
    /// 源文件绝对路径
    required String path,

    /// ffprobe format_name(如 "mov,mp4,m4a,3gp,3g2,mj2")
    required String formatName,

    /// 总时长
    required Duration duration,

    /// 首个视频流宽度
    required int width,

    /// 首个视频流高度
    required int height,

    /// 源帧率;部分编码器输出 0/0 时为 null
    double? fps,

    /// 视频流 codec_name(如 "h264")
    required String codec,
  }) = _VideoInfo;

  factory VideoInfo.fromJson(Map<String, dynamic> json) =>
      _$VideoInfoFromJson(json);
}

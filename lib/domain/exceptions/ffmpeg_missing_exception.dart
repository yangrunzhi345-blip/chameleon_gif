import 'file_pick_exception.dart';

/// FFmpeg/ffprobe 组件缺失(桌面端依赖系统二进制,`ProcessException` 映射,
/// 语义等价 CLI 的 exit 127)。
class FFmpegMissingException extends FilePickException {
  const FFmpegMissingException({super.cause})
    : super(
        errorCode: 'GIF_127_PROBE_MISSING',
        userMessage: 'FFmpeg 组件缺失,请安装 ffmpeg 后重试',
      );

  @override
  String toString() => 'FFmpegMissingException($errorCode): $userMessage';
}

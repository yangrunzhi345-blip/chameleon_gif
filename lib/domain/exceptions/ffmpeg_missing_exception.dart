import 'file_pick_exception.dart';

/// FFmpeg/ffprobe 组件缺失(桌面端依赖系统二进制,`ProcessException` 映射,
/// 语义等价 CLI 的 exit 127)。
///
/// [kind] 区分调用场景:'PROBE'(P1 探测)| 'ENCODE'(P3 转码),决定错误码
/// `GIF_127_<KIND>_MISSING`。
class FFmpegMissingException extends FilePickException {
  const FFmpegMissingException({super.cause, String kind = 'PROBE'})
    : super(
        errorCode: 'GIF_127_${kind}_MISSING',
        userMessage: 'FFmpeg 组件缺失,请安装 ffmpeg 后重试',
      );

  @override
  String toString() => 'FFmpegMissingException($errorCode): $userMessage';
}

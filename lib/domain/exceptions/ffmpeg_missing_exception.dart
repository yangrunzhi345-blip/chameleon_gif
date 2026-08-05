import 'file_pick_exception.dart';

/// FFmpeg/ffprobe 组件缺失(桌面端依赖系统二进制,`ProcessException` 映射,
/// 语义等价 CLI 的 exit 127)。
///
/// 归属说明:虽继承 [FilePickException] 族(源缺失语义),ENCODE 场景亦
/// 复用本类(ErrorHandler exit 127 分类,与 PROBE 场景共用组件缺失提示),
/// 以 [kind] 区分调用场景;捕获 FilePickException 的调用方据此判断——
/// ENCODE 场景属转换失败,不应当作文件选择失败处理。
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

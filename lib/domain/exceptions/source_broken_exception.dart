import 'file_pick_exception.dart';

/// 源文件损坏或格式异常(ffprobe 特征 `Invalid data found` / moov 缺失,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class SourceBrokenException extends FilePickException {
  const SourceBrokenException({required super.errorCode, super.cause})
    : super(userMessage: '视频文件损坏或格式异常');

  @override
  String toString() => 'SourceBrokenException($errorCode): $userMessage';
}

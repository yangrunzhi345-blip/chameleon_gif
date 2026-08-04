import 'file_pick_exception.dart';

/// 源文件不存在或已被移动(ffprobe 特征 `No such file or directory`,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class SourceMissingException extends FilePickException {
  const SourceMissingException({required super.errorCode, super.cause})
    : super(userMessage: '源文件不存在或已被移动');

  @override
  String toString() => 'SourceMissingException($errorCode): $userMessage';
}

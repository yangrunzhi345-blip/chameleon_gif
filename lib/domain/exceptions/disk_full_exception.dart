import 'conversion_exception.dart';

/// 磁盘空间不足(ffmpeg 特征 `No space left on device`,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class DiskFullException extends ConversionException {
  const DiskFullException({required super.errorCode, super.cause})
    : super(userMessage: '磁盘空间不足,请清理后重试');

  @override
  String toString() => 'DiskFullException($errorCode): $userMessage';
}

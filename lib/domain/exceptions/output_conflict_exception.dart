import 'conversion_exception.dart';

/// 输出文件已存在且禁止覆盖(ffmpeg 特征 `Output file already exists`,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class OutputConflictException extends ConversionException {
  const OutputConflictException({required super.errorCode, super.cause})
    : super(userMessage: '输出文件已存在');

  @override
  String toString() => 'OutputConflictException($errorCode): $userMessage';
}

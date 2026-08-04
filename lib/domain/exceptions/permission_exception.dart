import 'conversion_exception.dart';

/// 输出位置无写入权限(ffmpeg 特征 `Permission denied`,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class PermissionException extends ConversionException {
  const PermissionException({required super.errorCode, super.cause})
    : super(userMessage: '没有文件写入权限');

  @override
  String toString() => 'PermissionException($errorCode): $userMessage';
}

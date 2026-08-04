import 'conversion_exception.dart';

/// 通用编码失败(非 0 退出且无特征行匹配,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表兜底分支)。
class EncodeException extends ConversionException {
  const EncodeException({required super.errorCode, super.cause})
    : super(userMessage: '转换失败,请重试或调整参数');

  @override
  String toString() => 'EncodeException($errorCode): $userMessage';
}

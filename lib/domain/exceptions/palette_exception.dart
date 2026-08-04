import 'conversion_exception.dart';

/// 调色板生成失败(exit 1 且 stderr 含 palette 关键词,
/// 映射见 docs/08-FFmpeg设计.md §8.3.5 错误映射表)。
class PaletteException extends ConversionException {
  const PaletteException({required super.errorCode, super.cause})
    : super(userMessage: '调色板生成失败,请调整参数后重试');

  @override
  String toString() => 'PaletteException($errorCode): $userMessage';
}

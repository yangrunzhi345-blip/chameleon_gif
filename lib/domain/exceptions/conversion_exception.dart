import 'domain_exception.dart';

/// 转换流程异常基类(编码/调色板/IO 失败,docs/11-开发规范.md §11.3 层级)。
///
/// 覆盖 FFmpeg 转码阶段的可预期失败;具体子类见 [DiskFullException] /
/// [PermissionException] / [OutputConflictException] / [PaletteException] /
/// [EncodeException]。
class ConversionException extends DomainException {
  const ConversionException({
    required super.errorCode,
    required super.userMessage,
    super.cause,
  });

  @override
  String toString() => 'ConversionException($errorCode): $userMessage';
}

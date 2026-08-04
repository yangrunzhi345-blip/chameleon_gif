import 'domain_exception.dart';

/// 文件选择/解析族异常基类(docs/11-开发规范.md §11.3 层级)。
///
/// 覆盖"选文件失败"与"选到但解析失败"两类;具体子类见
/// [SourceBrokenException] / [SourceMissingException]。
class FilePickException extends DomainException {
  const FilePickException({
    required super.errorCode,
    required super.userMessage,
    super.cause,
  });

  @override
  String toString() => 'FilePickException($errorCode): $userMessage';
}

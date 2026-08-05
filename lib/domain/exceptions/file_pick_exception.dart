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

  /// 解析失败兜底(GIF_PARSE_UNKNOWN;多调用点共用,防错误码/文案漂移)。
  factory FilePickException.parseUnknown({Object? cause}) {
    return FilePickException(
      errorCode: 'GIF_PARSE_UNKNOWN',
      userMessage: '视频解析失败,请稍后重试',
      cause: cause,
    );
  }

  /// ffprobe 不可达/启动失败(GIF_PROBE_UNREACHABLE;文案与既有调用点一致)。
  factory FilePickException.probeUnreachable({Object? cause}) {
    return FilePickException(
      errorCode: 'GIF_PROBE_UNREACHABLE',
      userMessage: '视频解析服务不可用,请稍后重试',
      cause: cause,
    );
  }

  @override
  String toString() => 'FilePickException($errorCode): $userMessage';
}

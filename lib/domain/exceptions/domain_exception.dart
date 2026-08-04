/// 领域异常基类(业务可预期失败,见 docs/11-开发规范.md §11.3)。
///
/// 携带 [errorCode](格式 `GIF_<EXITCODE>_<KIND>`,见 docs/08-FFmpeg设计.md §8.3.5)
/// 与 [userMessage](中文用户可操作提示);技术原因存 [cause] 供日志排查。
abstract class DomainException implements Exception {
  const DomainException({
    required this.errorCode,
    required this.userMessage,
    this.cause,
  });

  /// 稳定错误码(入库/上报用,如 `GIF_1_SOURCE_BROKEN`)
  final String errorCode;

  /// 面向用户的中文提示(不含原始路径等敏感信息)
  final String userMessage;

  /// 底层技术原因(仅日志使用,不展示给用户)
  final Object? cause;

  @override
  String toString() => 'DomainException($errorCode): $userMessage';
}

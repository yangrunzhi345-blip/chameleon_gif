/// 保存到系统相册的结果(平台差异收敛点,docs/04-系统架构.md Platform 层)。
///
/// 契约:
/// - [GallerySaveStatus.saved]:已入库,携带相册内展示路径与 content URI
///   (URI 供"打开相册"定位);
/// - [GallerySaveStatus.failed]:保存失败,[message] 为用户可读中文提示
///   (磁盘满/IO 错误/系统版本过低需改用分享),不泄露原始路径(§5.4);
/// - [GallerySaveStatus.unsupported]:当前平台无相册能力(桌面等),
///   调用方视为无操作。
library;

enum GallerySaveStatus { saved, failed, unsupported }

class GallerySaveResult {
  const GallerySaveResult.saved({required this.displayPath, this.uri})
    : status = GallerySaveStatus.saved,
      message = null;

  const GallerySaveResult.failed(String this.message)
    : status = GallerySaveStatus.failed,
      displayPath = null,
      uri = null;

  const GallerySaveResult.unsupported()
    : status = GallerySaveStatus.unsupported,
      displayPath = null,
      uri = null,
      message = null;

  final GallerySaveStatus status;

  /// 相册内展示路径(如 `Pictures/GIFForge/demo.gif`)。
  final String? displayPath;

  /// 相册条目的 content URI(定位用)。
  final String? uri;

  /// 失败原因(用户可读中文)。
  final String? message;
}

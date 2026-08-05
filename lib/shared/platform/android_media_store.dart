import 'package:flutter/services.dart';

import 'gallery_save_result.dart';

/// Android 相册/分享通道桥(原生侧 MediaStoreChannel.kt)。
///
/// channel: `com.chameleongif.chameleon_gif/media_store`;原生返回统一 Map
/// {status, displayPath?, uri?, message?},与 [GallerySaveResult] 一一对应。
/// 桌面等无原生实现的宿主调用抛 MissingPluginException → 视为 unsupported。
class AndroidMediaStoreSaver {
  const AndroidMediaStoreSaver({
    this.channel = const MethodChannel(_channelName),
  });

  static const _channelName = 'com.chameleongif.chameleon_gif/media_store';

  final MethodChannel channel;

  /// 复制 [sourcePath] 到系统相册(Pictures/GIFForge),返回相册内展示路径与
  /// content URI;失败返回中文提示;原生缺失返回 unsupported。
  Future<GallerySaveResult> saveToGallery(
    String sourcePath, {
    String? displayName,
  }) async {
    try {
      final raw = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'saveToGallery',
        {'path': sourcePath, 'displayName': displayName},
      );
      return _parse(raw);
    } on PlatformException catch (e) {
      return GallerySaveResult.failed('保存到相册失败:${e.message ?? '未知错误'}');
    } on MissingPluginException {
      return const GallerySaveResult.unsupported();
    }
  }

  /// 打开相册定位条目([uri] 非空时);失败静默(尽力语义)。
  Future<void> openGallery({String? uri}) async {
    try {
      await channel.invokeMethod<void>('openGallery', {'uri': uri});
    } on PlatformException {
      // 尽力语义:无相册应用或失败不影响流程
    } on MissingPluginException {
      // 桌面等:无操作
    }
  }

  /// 系统分享面板发送 [path](FileProvider);失败静默。
  Future<void> shareFile(String path) async {
    try {
      await channel.invokeMethod<void>('shareFile', {'path': path});
    } on PlatformException {
      // 尽力语义
    } on MissingPluginException {
      // 桌面等:无操作
    }
  }

  GallerySaveResult _parse(Map<dynamic, dynamic>? raw) {
    final status = raw?['status'] as String?;
    switch (status) {
      case 'saved':
        return GallerySaveResult.saved(
          displayPath: raw?['displayPath'] as String? ?? '',
          uri: raw?['uri'] as String?,
        );
      case 'failed':
        return GallerySaveResult.failed(
          raw?['message'] as String? ?? '保存到相册失败',
        );
      default:
        return const GallerySaveResult.unsupported();
    }
  }
}

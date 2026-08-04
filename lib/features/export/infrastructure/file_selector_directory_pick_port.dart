import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/repository_interfaces/directory_pick_port.dart';

/// [DirectoryPickPort] 的 file_selector 实现(P4-WP4)。
///
/// 桌面(Linux/Windows)经 XDG desktop portal / 系统对话框选目录;
/// 轻量 WM 缺 portal 时抛 [PlatformException] → 包装 [FilePickException]
/// 中文提示,不崩溃。
class FileSelectorDirectoryPickPort implements DirectoryPickPort {
  const FileSelectorDirectoryPickPort();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    try {
      return await getDirectoryPath(initialDirectory: initialDirectory);
    } on PlatformException {
      throw const FilePickException(
        errorCode: 'GIF_DIR_PICK_FAILED',
        userMessage: '无法打开目录选择器,请检查系统桌面门户',
      );
    }
  }
}

import 'package:file_picker/file_picker.dart';

import '../../../domain/repository_interfaces/file_pick_port.dart';

/// [FilePickPort] 的 file_picker 实现(扩展名过滤)。
class FilePickerPortImpl implements FilePickPort {
  const FilePickerPortImpl();

  /// 图片→GIF 支持的扩展名
  static const kImageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  @override
  Future<String?> pickMp4() async {
    final result = await _pick(extensions: const ['mp4'], allowMultiple: false);
    return result == null || result.isEmpty ? null : result.first;
  }

  @override
  Future<List<String>?> pickMp4s() =>
      _pick(extensions: const ['mp4'], allowMultiple: true);

  @override
  Future<List<String>?> pickImages() =>
      _pick(extensions: kImageExtensions, allowMultiple: true);

  /// 共享选择逻辑;多选时空选归一为 null(取消语义)。
  Future<List<String>?> _pick({
    required List<String> extensions,
    required bool allowMultiple,
  }) async {
    // file_picker 11.x:静态方法(不再有 .platform 实例)
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: allowMultiple,
    );
    final files = result?.files;
    if (files == null || files.isEmpty) return null;
    final paths = files
        .map((f) => f.path)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();
    return paths.isEmpty ? null : paths;
  }
}

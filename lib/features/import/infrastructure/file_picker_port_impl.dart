import 'package:file_picker/file_picker.dart';

import '../../../domain/repository_interfaces/file_pick_port.dart';

/// [FilePickPort] 的 file_picker 实现(仅 MP4 过滤)。
class FilePickerPortImpl implements FilePickPort {
  const FilePickerPortImpl();

  @override
  Future<String?> pickMp4() async {
    // file_picker 11.x:静态方法(不再有 .platform 实例)
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4'],
    );
    final files = result?.files;
    if (files == null || files.isEmpty) return null;
    final path = files.first.path;
    return (path == null || path.isEmpty) ? null : path;
  }
}

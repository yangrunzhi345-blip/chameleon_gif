/// 文件选择端口(M01 导入:MP4 源文件选取,见 docs/06-模块设计.md §6.2)。
///
/// 取消选择返回 null(与 file_picker/file_selector 语义一致)。
abstract interface class FilePickPort {
  Future<String?> pickMp4();

  /// 多选 MP4 源文件(P6-WP1 批量导入);取消/空选归一为 null。
  Future<List<String>?> pickMp4s();
}

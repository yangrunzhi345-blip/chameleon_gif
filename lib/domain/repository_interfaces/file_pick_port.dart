/// 文件选择端口(M01 导入:MP4 源文件选取,见 docs/06-模块设计.md §6.2)。
///
/// 取消选择返回 null(与 file_picker/file_selector 语义一致)。
abstract interface class FilePickPort {
  Future<String?> pickMp4();
}

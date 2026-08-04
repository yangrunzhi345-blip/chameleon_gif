/// 目录选择端口(P4-WP4;取消返回 null,与 [FilePickPort] 语义一致)。
abstract interface class DirectoryPickPort {
  /// 打开系统目录选择器;[initialDirectory] 为初始目录(可空)。
  Future<String?> pickDirectory({String? initialDirectory});
}

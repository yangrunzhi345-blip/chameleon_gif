/// 输出文件路径构造(纯函数,可单测;P4-WP4 导出目录)。
///
/// 命名 `<源名>_<taskId>.gif` 保证同源多次导出互不覆盖;
/// Windows 非法字符 `<>:"/\|?*` 清洗为 `_`;源名为空兜底 `video`。
String buildOutputFileName(String sourcePath, int taskId) {
  final segments = sourcePath.split(RegExp(r'[\\/]'));
  var base = segments.last;
  final dot = base.lastIndexOf('.');
  if (dot > 0) base = base.substring(0, dot);
  if (base.isEmpty) base = 'video';
  final cleaned = base.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
  return '${cleaned}_$taskId.gif';
}

/// 输出目录 + 源文件 + taskId → 输出完整路径(目录去尾部分隔符,防 `//`)。
String resolveOutputPath({
  required String outputDir,
  required String sourcePath,
  required int taskId,
}) {
  final dir = outputDir.endsWith('/') || outputDir.endsWith(r'\')
      ? outputDir.substring(0, outputDir.length - 1)
      : outputDir;
  return '$dir/${buildOutputFileName(sourcePath, taskId)}';
}

/// FFmpeg stderr 日志分级解析(纯 Dart,可单测,docs/08 §8.3.4)。
///
/// 规则:含 `[error]`/`Error`/`Invalid` → 错误;含 `[warning]`/`Warning` →
/// 警告;其余 → 信息。长行截断([maxLineLength])避免日志膨胀。
class LogParser {
  const LogParser();

  /// 单行日志最大保留长度,超出截断。
  static const maxLineLength = 500;

  void parse(
    String line, {
    required void Function(String) onError,
    required void Function(String) onWarn,
    required void Function(String) onInfo,
  }) {
    final lower = line.toLowerCase();
    final text = line.length > maxLineLength
        ? '${line.substring(0, maxLineLength)}…'
        : line;
    if (lower.contains('[error]') ||
        lower.contains('error') ||
        lower.contains('invalid')) {
      onError(text);
    } else if (lower.contains('[warning]') || lower.contains('warning')) {
      onWarn(text);
    } else {
      onInfo(text);
    }
  }
}

/// FFmpeg 时间参数格式化(docs/08-FFmpeg设计.md §8.3.2)。
///
/// ffmpeg 的 `-ss`/`-to` 接受 `HH:MM:SS.mmm` 形式,毫秒精度即满足 GIF
/// 起止裁剪需求(毫秒级以下按截断处理)。
String formatFfmpegTime(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '$h:$m:$s.$ms';
}

/// 人读时长格式化(「N 分 M 秒」,<1 分钟显示秒;导出完成弹窗/进度面板复用)。
String formatHumanDuration(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '$s 秒';
  return '${s ~/ 60} 分 ${s % 60} 秒';
}

/// `MM:SS` 显示格式化(时间轴/参数表单的选区标签,4 处 UI 复用去重)。
///
/// [fractionDigits] 秒的小数位:0 → `05`、1 → `03.5`、3 → `03.200`
/// (补零按位数,`padLeft(fractionDigits + 3, '0')`)。
String formatMmSs(int totalMs, {int fractionDigits = 0}) {
  final m = (totalMs ~/ 60000).toString().padLeft(2, '0');
  final sec = totalMs % 60000;
  if (fractionDigits == 0) {
    return '$m:${(sec ~/ 1000).toString().padLeft(2, '0')}';
  }
  final whole = (sec ~/ 1000).toString().padLeft(2, '0');
  final frac = (sec % 1000)
      .toString()
      .padLeft(3, '0')
      .substring(0, fractionDigits);
  return '$m:$whole.$frac';
}

/// 时间输入解析(P4 表单,与 [formatFfmpegTime] 对称)。
///
/// 支持 `HH:MM:SS[.mmm]` / `MM:SS[.mmm]` / 裸秒 `S[.mmm]`;分/秒必须 <60;
/// 毫秒 1–3 位补零;空串/空白/非法 → null(调用方语义:start=0,end=到结尾)。
Duration? parseFfmpegTime(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final match = RegExp(
    r'^(\d+):(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?$'
    r'|^(\d+):(\d{1,2})(?:\.(\d{1,3}))?$'
    r'|^(\d+)(?:\.(\d{1,3}))?$',
  ).firstMatch(text);
  if (match == null) return null;

  // 9 组:1-4 HH:MM:SS[.mmm] | 5-7 MM:SS[.mmm] | 8-9 裸秒[.mmm]
  final groups = match.groups([1, 2, 3, 4, 5, 6, 7, 8, 9]);
  int hours = 0, minutes = 0, seconds = 0, millis = 0;

  if (groups[0] != null) {
    // HH:MM:SS[.mmm]
    hours = int.parse(groups[0]!);
    minutes = int.parse(groups[1]!);
    seconds = int.parse(groups[2]!);
    millis = _parseMillis(groups[3]);
  } else if (groups[4] != null) {
    // MM:SS[.mmm]
    minutes = int.parse(groups[4]!);
    seconds = int.parse(groups[5]!);
    millis = _parseMillis(groups[6]);
  } else {
    // 裸秒 S[.mmm]
    seconds = int.parse(groups[7]!);
    millis = _parseMillis(groups[8]);
  }

  if (minutes >= 60 || seconds >= 60) return null;
  return Duration(
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    milliseconds: millis,
  );
}

int _parseMillis(String? raw) {
  if (raw == null) return 0;
  // 1–3 位毫秒:按位数补零(「5」→ 500ms? 否——按小数位补零:「.5」→ 500ms)
  return int.parse(raw.padRight(3, '0'));
}

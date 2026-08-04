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

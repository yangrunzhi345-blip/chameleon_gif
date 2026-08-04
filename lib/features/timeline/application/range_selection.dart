/// 时间轴起止选区(不可变;普通手写类,与 PreviewState 风格一致)。
///
/// 契约:[start] <= [end],均钳制在 [Duration.zero, 视频时长] 内
/// (由 TimelineController 保证)。
class RangeSelection {
  const RangeSelection({required this.start, required this.end});

  final Duration start;
  final Duration end;

  RangeSelection copyWith({Duration? start, Duration? end}) {
    return RangeSelection(start: start ?? this.start, end: end ?? this.end);
  }

  @override
  bool operator ==(Object other) =>
      other is RangeSelection && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'RangeSelection($start — $end)';
}

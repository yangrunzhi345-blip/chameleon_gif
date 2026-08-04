/// 起点/终点归一化:起点大于终点时**自动交换**(P4 阶段门契约,
/// docs/12-开发计划.md §12.3;时间轴与导出表单共用)。
///
/// 返回交换后的 (start, end);`a == b` 时不交换(相等无意义,由调用方
/// 决定拒绝语义)。
(Duration, Duration) normalizeRange(Duration a, Duration b) {
  if (a > b) return (b, a);
  return (a, b);
}

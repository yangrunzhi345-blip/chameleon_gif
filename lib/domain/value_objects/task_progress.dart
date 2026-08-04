import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_progress.freezed.dart';
part 'task_progress.g.dart';

/// 任务进度快照(实时值,docs/07-数据库设计.md §7.4)。
@freezed
abstract class TaskProgress with _$TaskProgress {
  const factory TaskProgress({
    /// 所属任务 id
    required int taskId,

    /// 完成度 0.0–1.0(源自 out_time_us / 裁剪时长,钳制)
    @Default(0.0) double percent,

    /// 已耗时(编码输出时间戳,相对裁剪起点)
    @Default(Duration.zero) Duration elapsed,

    /// 预估剩余时长;速度数据缺失时按已耗时线性预估,可为 null
    Duration? remaining,

    /// 写入速度 KB/s(total_size 差分,0 = 无数据)
    @Default(0) int speedKbPerSec,
  }) = _TaskProgress;

  factory TaskProgress.fromJson(Map<String, dynamic> json) =>
      _$TaskProgressFromJson(json);
}

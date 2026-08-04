/// 转换任务状态(状态机见 docs/06-模块设计.md §6.3)。
///
/// 持久化时以 index 存 int(见 ExportTask.state 字段)。
enum TaskState {
  /// 已创建,尚未入队
  idle,

  /// 排队等待执行
  queued,

  /// 正在执行
  running,

  /// 已完成(终态)
  completed,

  /// 已失败(可重试)
  failed,

  /// 已取消(终态)
  cancelled,
}

extension TaskStateX on TaskState {
  /// 是否为终态(不可再转移)
  bool get isFinal =>
      this == TaskState.completed || this == TaskState.cancelled;

  /// 是否为待恢复状态(应用重启后重新排队,见 docs/07-数据库设计.md)
  bool get isPending => this == TaskState.queued || this == TaskState.running;
}

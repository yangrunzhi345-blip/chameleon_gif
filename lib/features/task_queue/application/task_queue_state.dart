import '../../../domain/entities/export_task.dart';

/// 任务队列 UI 状态(docs/09-状态管理.md §9.2 层次一,常驻)。
///
/// 不可变;状态一律整体重建(_refresh 直接构造),不提供 copyWith
/// (避免 `active ?? this.active` 无法显式置 null 的隐患)。
class TaskQueueState {
  const TaskQueueState({this.tasks = const [], this.active});

  /// 全部任务(按入队序,终态在尾部)。
  final List<ExportTask> tasks;

  /// 当前执行中的任务(单并发槽)。
  final ExportTask? active;
}

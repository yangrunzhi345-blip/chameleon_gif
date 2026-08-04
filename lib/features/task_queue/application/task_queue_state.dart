import '../../../domain/entities/export_task.dart';

/// 任务队列 UI 状态(docs/09-状态管理.md §9.2 层次一,常驻)。
///
/// 不可变;状态一律整体重建(_refresh 直接构造),不提供 copyWith
/// (避免 `active ?? this.active` 无法显式置 null 的隐患)。
class TaskQueueState {
  const TaskQueueState({this.tasks = const [], this.running = const []});

  /// 全部任务(按 id 序,终态在尾部)。
  final List<ExportTask> tasks;

  /// 执行中任务(≤ 并发度,P6 双槽)。
  final List<ExportTask> running;

  /// 兼容视图:首个执行中任务(activeTaskProvider 无 UI 消费,保留最小改动)。
  ExportTask? get active => running.isEmpty ? null : running.first;
}

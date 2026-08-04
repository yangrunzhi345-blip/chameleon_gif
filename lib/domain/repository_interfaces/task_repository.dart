import '../entities/export_task.dart';

/// 转换任务仓储接口(Isar 实现于 P5 落地,见 docs/12-开发计划.md P5-WP1)。
///
/// 职责:任务状态流持久化,支撑崩溃恢复与队列恢复。
abstract interface class TaskRepository {
  /// 新增任务,返回自增 id
  Future<int> add(ExportTask task);

  Future<void> update(ExportTask task);

  Future<void> delete(int id);

  Future<ExportTask?> byId(int id);

  /// 待恢复任务(queued/running),用于应用启动后重新排队
  Future<List<ExportTask>> pending();

  Future<List<ExportTask>> all();
}

import '../entities/export_task.dart';

/// 转换任务仓储接口(Isar 实现于 P5 落地,见 docs/12-开发计划.md P5-WP1)。
///
/// 职责:任务状态流持久化,支撑崩溃恢复与队列恢复。
abstract interface class TaskRepository {
  /// 新增任务,返回自增 id
  Future<int> add(ExportTask task);

  /// 更新任务(状态机推进/进度/错误信息持久化)。
  Future<void> update(ExportTask task);

  /// 删除任务。
  Future<void> delete(int id);

  /// 按 id 查询;不存在返回 null。
  Future<ExportTask?> byId(int id);

  /// 待恢复任务(queued/running,按 id 升序),用于应用启动后重新排队
  Future<List<ExportTask>> pending();

  /// 全部任务(按 id 升序)。
  Future<List<ExportTask>> all();
}

import 'package:isar_community/isar.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/entities/export_task.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../../domain/value_objects/task_state.dart';
import 'schemas/export_task_schema.dart';

/// [TaskRepository] 的 Isar 实现(P5-WP1;崩溃恢复持久化,§8.3.7)。
///
/// 查询:恢复扫描 `pending()` 用 `state < completed.index`(queued+running,
/// 与 [TaskState.isPending] 语义一致);`all()` 主键序 = id 升序。
/// 容错:`settingsJson` 损坏行记 error 日志(含 id)后跳过/返回 null,
/// 列表永不全量失败(§7.6 R-04 不动 schema)。
class IsarTaskRepository implements TaskRepository {
  IsarTaskRepository(this._isar, {required AppLogger logger})
    : _logger = logger;

  final Isar _isar;
  final AppLogger _logger;

  @override
  Future<int> add(ExportTask task) async {
    final schema = ExportTaskSchema.fromEntity(task);
    // fromEntity 显式赋 task.id(=0)会覆盖 autoIncrement 哨兵,
    // 新任务重置为哨兵以触发自增(put 返回新 id)
    if (task.id <= 0) schema.id = Isar.autoIncrement;
    return _isar.writeTxn(() => _isar.exportTaskSchemas.put(schema));
  }

  @override
  Future<void> update(ExportTask task) async {
    await _isar.writeTxn(
      () => _isar.exportTaskSchemas.put(ExportTaskSchema.fromEntity(task)),
    );
  }

  @override
  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.exportTaskSchemas.delete(id));
  }

  @override
  Future<ExportTask?> byId(int id) async {
    final schema = await _isar.exportTaskSchemas
        .where()
        .idEqualTo(id)
        .findFirst();
    return schema == null ? null : _safeToEntity(schema, 'task byId id=$id');
  }

  @override
  Future<List<ExportTask>> pending() async {
    // queued(1)+running(2) 闭区间,排除 idle(0)/终态(≥3),与 isPending 语义一致
    final schemas = await _isar.exportTaskSchemas
        .where()
        .stateBetween(
          TaskState.queued.index,
          TaskState.running.index,
          includeLower: true,
          includeUpper: true,
        )
        .findAll();
    return schemas
        .map((s) => _safeToEntity(s, 'task pending id=${s.id}'))
        .whereType<ExportTask>()
        .toList()
      // 接口契约(id 升序,与 InMemory 对齐):stateBetween 走 state 索引,
      // 返回顺序按 state 值(queued 在前),恢复重排必须按提交序
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<List<ExportTask>> all() async {
    final schemas = await _isar.exportTaskSchemas.where().findAll();
    return schemas
        .map((s) => _safeToEntity(s, 'task all id=${s.id}'))
        .whereType<ExportTask>()
        .toList();
  }

  /// settingsJson 损坏容错:记日志并返回 null(列表行跳过)。
  ExportTask? _safeToEntity(ExportTaskSchema schema, String tag) {
    try {
      return schema.toEntity();
    } on Object catch (e, st) {
      _logger.e('任务记录解析失败($tag),已跳过', error: e, stackTrace: st);
      return null;
    }
  }
}

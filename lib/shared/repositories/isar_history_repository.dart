import 'package:isar_community/isar.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/entities/export_history.dart';
import '../../domain/repository_interfaces/history_repository.dart';
import 'schemas/export_history_schema.dart';

/// [HistoryRepository] 的 Isar 实现(P5-WP1)。
///
/// 历史为不可变快照,仅读/删;`list()` 经 createdAt 索引倒序。
/// 容错:`settingsJson` 损坏行记 error 日志(含 id)后跳过/返回 null,
/// 列表永不全量失败(§7.6 R-04 不动 schema)。
class IsarHistoryRepository implements HistoryRepository {
  IsarHistoryRepository(this._isar, {required AppLogger logger})
    : _logger = logger;

  final Isar _isar;
  final AppLogger _logger;

  @override
  Future<int> add(ExportHistory history) async {
    final schema = ExportHistorySchema.fromEntity(history);
    // fromEntity 显式赋 id(=0)会覆盖 autoIncrement 哨兵,
    // 新记录重置为哨兵以触发自增(put 返回新 id)
    if (history.id <= 0) schema.id = Isar.autoIncrement;
    return _isar.writeTxn(() => _isar.exportHistorySchemas.put(schema));
  }

  @override
  Future<void> delete(int id) async {
    await _isar.writeTxn(() => _isar.exportHistorySchemas.delete(id));
  }

  @override
  Future<void> clear() async {
    await _isar.writeTxn(() => _isar.exportHistorySchemas.clear());
  }

  @override
  Future<List<ExportHistory>> list() async {
    final schemas = await _isar.exportHistorySchemas
        .where()
        .sortByCreatedAtDesc()
        .findAll();
    return schemas
        .map((s) => _safeToEntity(s, 'history list id=${s.id}'))
        .whereType<ExportHistory>()
        .toList();
  }

  @override
  Future<ExportHistory?> byId(int id) async {
    final schema = await _isar.exportHistorySchemas
        .where()
        .idEqualTo(id)
        .findFirst();
    return schema == null ? null : _safeToEntity(schema, 'history byId id=$id');
  }

  /// settingsJson 损坏容错:记日志并返回 null(列表行跳过)。
  ExportHistory? _safeToEntity(ExportHistorySchema schema, String tag) {
    try {
      return schema.toEntity();
    } on Object catch (e, st) {
      _logger.e('历史记录解析失败($tag),已跳过', error: e, stackTrace: st);
      return null;
    }
  }
}

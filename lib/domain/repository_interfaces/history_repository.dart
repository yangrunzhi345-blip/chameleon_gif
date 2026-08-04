import '../entities/export_history.dart';

/// 转换历史仓储接口(Isar 实现于 P5 落地,见 docs/12-开发计划.md P5-WP1)。
///
/// 历史为转换完成后的不可变快照,仅读/删,不修改。
abstract interface class HistoryRepository {
  Future<int> add(ExportHistory history);

  Future<void> delete(int id);

  Future<void> clear();

  /// 按完成时间倒序
  Future<List<ExportHistory>> list();

  Future<ExportHistory?> byId(int id);
}

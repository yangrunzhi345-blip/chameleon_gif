import '../../domain/entities/export_history.dart';
import '../../domain/repository_interfaces/history_repository.dart';

/// [HistoryRepository] 内存实现(测试注入用;生产走 Isar 仓储,
/// 见 isar_history_repository.dart)。按完成时间倒序返回。
class InMemoryHistoryRepository implements HistoryRepository {
  final Map<int, ExportHistory> _histories = {};
  int _nextId = 1;

  @override
  Future<int> add(ExportHistory history) async {
    final id = _nextId++;
    _histories[id] = ExportHistory(
      id: id,
      videoPath: history.videoPath,
      outputPath: history.outputPath,
      settings: history.settings,
      durationMs: history.durationMs,
      outputSizeBytes: history.outputSizeBytes,
      createdAt: history.createdAt,
      sourceDurationMs: history.sourceDurationMs,
      outputFrameCount: history.outputFrameCount,
      imagePaths: history.imagePaths,
    );
    return id;
  }

  @override
  Future<void> delete(int id) async {
    _histories.remove(id);
  }

  @override
  Future<void> clear() async {
    _histories.clear();
  }

  @override
  Future<List<ExportHistory>> list() async =>
      _histories.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<ExportHistory?> byId(int id) async => _histories[id];
}

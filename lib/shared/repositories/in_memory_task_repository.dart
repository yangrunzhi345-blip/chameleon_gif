import '../../domain/entities/export_task.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../../domain/value_objects/task_state.dart';

/// [TaskRepository] 内存实现(P3 过渡;P5-WP1 替换为 Isar 仓储,
/// 见 docs/12-开发计划.md)。
///
/// 支持预种子任务(测试模拟"崩溃会话"恢复场景)。
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({List<ExportTask> seed = const []}) {
    for (final task in seed) {
      _tasks[task.id] = task;
      if (task.id >= _nextId) _nextId = task.id + 1;
    }
  }

  final Map<int, ExportTask> _tasks = {};
  int _nextId = 1;

  @override
  Future<int> add(ExportTask task) async {
    final id = _nextId++;
    _tasks[id] = ExportTask(
      id: id,
      videoPath: task.videoPath,
      outputPath: task.outputPath,
      settings: task.settings,
      state: task.state,
      progress: task.progress,
      errorCode: task.errorCode,
      errorDetail: task.errorDetail,
      retryCount: task.retryCount,
      createdAt: task.createdAt,
      startedAt: task.startedAt,
      finishedAt: task.finishedAt,
      imagePaths: task.imagePaths,
    );
    return id;
  }

  @override
  Future<void> update(ExportTask task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<void> delete(int id) async {
    _tasks.remove(id);
  }

  @override
  Future<ExportTask?> byId(int id) async => _tasks[id];

  @override
  Future<List<ExportTask>> pending() async =>
      _tasks.values.where((t) => t.state.isPending).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  @override
  Future<List<ExportTask>> all() async =>
      _tasks.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

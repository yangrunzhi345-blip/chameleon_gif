import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/export_task.dart';
import '../../domain/value_objects/task_state.dart';
import '../../features/task_queue/application/task_queue_providers.dart';
import '../../shared/providers/core_providers.dart';

/// 批量会话阶段(由 [derive] 计算,UI 仅消费 phase 驱动弹窗)。
enum BatchSessionPhase {
  /// 无批次(初始/已清理)
  none,

  /// 批次内任务未全部落定(不弹窗)
  running,

  /// 已落定且存在失败项且未点"否":先弹失败询问弹窗
  askRetry,

  /// 已落定且(无失败 || 已点"否"):弹最终完成弹窗
  finished,
}

/// 失败项展示数据(路径 + 用户可读错误)。
class BatchFailedItem {
  const BatchFailedItem({required this.path, this.errorDetail});

  final String path;
  final String? errorDetail;
}

/// 最终弹窗统计(预览按钮依赖成功任务的输出路径列表)。
class BatchStats {
  const BatchStats({
    required this.completed,
    required this.failed,
    required this.cancelled,
    this.completedGifPaths = const [],
  });

  final int completed;
  final int failed;
  final int cancelled;

  /// 成功且 outputPath 非空的任务输出路径(按入队顺序,预览列表用)。
  final List<String> completedGifPaths;
}

/// 批量会话状态(不可变;**只存声明字段**,派生数据由 [derive] 计算)。
///
/// 设计约束:本控制器不 watch 任务队列(避免在 [BatchImportController.start]
/// 的物化链上拉入 TaskManager 全链路,破坏轻量测试容器);派生(phase/
/// 统计/失败项)由 UI 层宿主 watch [taskQueueControllerProvider] 后经
/// [derive] 计算。
class BatchSessionState {
  const BatchSessionState({this.taskIds = const [], this.declined = false});

  /// 空会话(无批次)。
  const BatchSessionState.idle() : taskIds = const [], declined = false;

  /// 本批次入队 taskId 集合(登记顺序 = paths 顺序)。
  final List<int> taskIds;

  /// 失败询问弹窗是否已点"否"(点后跳过 askRetry 直接 finished)。
  final bool declined;
}

/// 批次派生纯函数(零容器可单测)。
///
/// 输入批次声明(taskIds + declined)与全量任务快照,输出阶段与派生数据:
/// - taskIds 为空 → none;
/// - 任一任务未落定(存在 queued/running/idle)→ running;
/// - 已落定且存在失败且未点"否" → askRetry;
/// - 其余 → finished(failed 仅入统计,不询问)。
/// "落定" = 每个任务 state ∈ {completed, failed, cancelled}(failed 对
/// 批次而言是"可询问"态;cancelled 不询问,仅在统计中体现)。
BatchSessionSnapshot derive({
  required List<int> taskIds,
  required List<ExportTask> tasks,
  required bool declined,
}) {
  if (taskIds.isEmpty) {
    return const BatchSessionSnapshot.phaseOnly(BatchSessionPhase.none);
  }
  final byId = {for (final t in tasks) t.id: t};
  final mine = <ExportTask>[];
  for (final id in taskIds) {
    final task = byId[id];
    if (task != null) mine.add(task);
  }
  final settled =
      mine.isNotEmpty &&
      mine.every(
        (t) =>
            t.state == TaskState.completed ||
            t.state == TaskState.failed ||
            t.state == TaskState.cancelled,
      );
  final failedList = mine.where((t) => t.state == TaskState.failed).toList();
  if (!settled) {
    return const BatchSessionSnapshot.phaseOnly(BatchSessionPhase.running);
  }
  final phase = (failedList.isNotEmpty && !declined)
      ? BatchSessionPhase.askRetry
      : BatchSessionPhase.finished;
  final completedList = mine
      .where((t) => t.state == TaskState.completed)
      .toList();
  return BatchSessionSnapshot(
    phase: phase,
    failedItems: failedList
        .map(
          (t) => BatchFailedItem(path: t.videoPath, errorDetail: t.errorDetail),
        )
        .toList(),
    stats: BatchStats(
      completed: completedList.length,
      failed: failedList.length,
      cancelled: mine.where((t) => t.state == TaskState.cancelled).length,
      completedGifPaths: completedList
          .map((t) => t.outputPath)
          .whereType<String>()
          .toList(),
    ),
  );
}

/// 批次派生结果(宿主消费)。
class BatchSessionSnapshot {
  const BatchSessionSnapshot({
    required this.phase,
    this.failedItems = const [],
    this.stats = const BatchStats(completed: 0, failed: 0, cancelled: 0),
  });

  const BatchSessionSnapshot.phaseOnly(this.phase)
    : failedItems = const [],
      stats = const BatchStats(completed: 0, failed: 0, cancelled: 0);

  final BatchSessionPhase phase;
  final List<BatchFailedItem> failedItems;
  final BatchStats stats;
}

/// 批量会话控制器(常驻非 autoDispose,app 层跨模块组合)。
///
/// 会话语义:一次"批量导入 → 全部落定 → 弹窗"的全过程。批次状态存本
/// 控制器([BatchImportController] 为 autoDispose,离开批量页即销毁,
/// 无法承担跨页面批次追踪);本控制器只维护声明(taskIds/declined),
/// 完成判定由 UI 层经 [derive] 派生(见类注释)。
/// 新批次 [begin] 直接替换旧会话(边界行为,不做合并)。
class BatchSessionController extends Notifier<BatchSessionState> {
  List<int> _taskIds = const [];
  bool _declined = false;

  @override
  BatchSessionState build() => const BatchSessionState.idle();

  /// 登记新批次(替换旧会话;declined 复位)。
  void begin(List<int> taskIds) {
    _taskIds = List.unmodifiable(taskIds);
    _declined = false;
    _rebuild();
  }

  /// 失败询问弹窗点"否":跳过 askRetry,进入 finished(仅弹一次)。
  void decline() {
    _declined = true;
    _rebuild();
  }

  /// 重试本批次内全部失败项(仅 failed → queued,已完成/取消的不动);
  /// 重试后经派生自动回到 running,再次落定后重新判定。
  Future<void> retryFailed() async {
    final controller = ref.read(taskQueueControllerProvider.notifier);
    final tasks = ref.read(taskQueueControllerProvider).tasks;
    for (final task in tasks) {
      if (_taskIds.contains(task.id) && task.state == TaskState.failed) {
        await controller.retry(task.id);
      }
    }
  }

  /// 清理批次(最终弹窗任一按钮后调用,防重复弹窗)。
  void clear() {
    _taskIds = const [];
    _declined = false;
    _rebuild();
  }

  /// 在系统文件管理器中打开本批次第一个成功输出的所在目录
  /// (done 态动作,UI 层仅转发;目录提取在功能层,与单文件
  /// [ExportController.openOutputFolder] 同模式)。
  Future<void> openOutputFolder(String outputPath) async {
    if (outputPath.isEmpty) return;
    await ref
        .read(platformAdapterProvider)
        .openFolder(File(outputPath).parent.path);
  }

  void _rebuild() {
    state = BatchSessionState(taskIds: _taskIds, declined: _declined);
  }
}

/// 批量会话 provider(常驻;与 controller 同文件定义,防循环 import)。
final batchSessionProvider =
    NotifierProvider<BatchSessionController, BatchSessionState>(
      BatchSessionController.new,
    );

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_history.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/providers/core_providers.dart';
import '../../task_queue/application/task_queue_providers.dart';

/// 历史列表控制器(docs/06 M05,docs/09 §9.2 层次一,常驻)。
///
/// 初始异步加载;订阅任务事件流,completed 时自动刷新(§9.5:
/// TaskQueue → completed → HistoryController → 列表刷新)。
/// delete/clear/retry 在 P5-WP3 落地,本阶段仅 list/reload。
class HistoryController extends Notifier<AsyncValue<List<ExportHistory>>> {
  StreamSubscription<ExportTask>? _taskSub;

  @override
  AsyncValue<List<ExportHistory>> build() {
    ref.onDispose(() => _taskSub?.cancel());
    final manager = ref.watch(taskManagerProvider);
    _taskSub ??= manager.taskEvents.listen((event) {
      if (event.state == TaskState.completed) {
        unawaited(reload());
      }
    });
    Future.microtask(reload);
    return const AsyncValue.loading();
  }

  /// 重新加载历史列表(时间倒序,仓储保证)。
  Future<void> reload() async {
    final list = await ref.read(historyRepositoryProvider).list();
    state = AsyncValue.data(list);
  }

  /// 清空全部历史(UI 层已二次确认;仅记录级,不删输出文件)。
  Future<void> clear() async {
    await ref.read(historyRepositoryProvider).clear();
    await reload();
  }
}

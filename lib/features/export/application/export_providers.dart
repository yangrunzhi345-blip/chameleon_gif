import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/throttle_stream.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/task_progress.dart';
import '../../task_queue/application/task_queue_providers.dart';
import 'export_controller.dart';
import 'export_state.dart';

/// 导出会话控制器(层次二,autoDispose)。
final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportFormState>(
      ExportController.new,
    );

/// 当前执行中的任务(层次三,只读视图)。
final activeTaskProvider = Provider<ExportTask?>(
  (ref) => ref.watch(taskQueueControllerProvider).active,
);

/// 导出进度流(200ms 尾缘节流,§9.3;只透传当前导出任务的进度)。
final exportProgressProvider = StreamProvider<TaskProgress>((ref) {
  final taskId = ref.watch(exportControllerProvider).taskId;
  final manager = ref.watch(taskManagerProvider);
  return throttleStream(
    manager.progressStream.where((p) => p.taskId == taskId),
    const Duration(milliseconds: 200),
  );
});

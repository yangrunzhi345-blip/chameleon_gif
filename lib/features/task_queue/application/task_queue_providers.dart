import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/throttle_stream.dart';
import '../../../domain/value_objects/task_progress.dart';
import '../../../shared/providers/core_providers.dart';
import 'task_manager.dart';
import 'task_queue_controller.dart';
import 'task_queue_state.dart';

/// 任务调度器(常驻,单并发槽)。
///
/// FFmpeg 服务经 [ffmpegServiceProvider](shared/providers,接口型,由
/// main() 注入实现)注入,模块内不感知具体引擎实现。
final taskManagerProvider = Provider<TaskManager>((ref) {
  return TaskManager(
    taskRepository: ref.watch(taskRepositoryProvider),
    historyRepository: ref.watch(historyRepositoryProvider),
    ffmpegService: ref.watch(ffmpegServiceProvider),
    platformAdapter: ref.watch(platformAdapterProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 任务队列状态(docs/09 §9.2 层次一,常驻)。
final taskQueueControllerProvider =
    NotifierProvider<TaskQueueController, TaskQueueState>(
      TaskQueueController.new,
    );

/// 单任务进度(队列页行内消费;200ms 尾缘节流,按 taskId 过滤,
/// 与 exportProgressProvider 同构互不干扰)。
final queueTaskProgressProvider = StreamProvider.autoDispose
    .family<TaskProgress, int>((ref, taskId) {
      final manager = ref.watch(taskManagerProvider);
      return throttleStream(
        manager.progressStream.where((p) => p.taskId == taskId),
        const Duration(milliseconds: 200),
      );
    });

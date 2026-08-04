import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/task_state.dart';
import '../application/task_queue_providers.dart';

/// 队列任务行(P6-WP2):状态图标 + 文件名 + 状态文案 + 进度 + 取消/重试。
///
/// 进度经 [queueTaskProgressProvider](按 taskId 过滤的 200ms 节流流);
/// 失败行显示 userMessage 并可重试;排队/执行中可取消。
class QueueTaskListItem extends ConsumerWidget {
  const QueueTaskListItem({super.key, required this.task});

  final ExportTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskQueueControllerProvider.notifier);
    final fileName = task.videoPath.split(RegExp(r'[\\/]')).last;
    final running = task.state == TaskState.running;

    return ListTile(
      leading: switch (task.state) {
        TaskState.running => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        TaskState.queued => const Icon(Icons.schedule),
        TaskState.failed => Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        _ => const Icon(Icons.hourglass_empty),
      },
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            running
                ? '转换中'
                : task.state == TaskState.failed
                ? (task.errorDetail ?? '失败')
                : task.state.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (running) _ProgressBar(taskId: task.id),
        ],
      ),
      trailing: task.state == TaskState.failed
          ? IconButton(
              tooltip: '重试',
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.retry(task.id),
            )
          : IconButton(
              tooltip: '取消',
              icon: const Icon(Icons.close),
              onPressed: () => controller.cancel(task.id),
            ),
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(queueTaskProgressProvider(taskId)).value;
    final percent = progress?.percent ?? 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: LinearProgressIndicator(value: percent, minHeight: 3),
    );
  }
}

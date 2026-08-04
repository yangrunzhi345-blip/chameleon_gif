import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/value_objects/task_state.dart';
import '../application/task_queue_providers.dart';
import 'queue_task_list_item.dart';

/// 任务队列页(P6-WP2,docs/09 §9.5 状态流"TaskQueueState → 任务列表")。
///
/// 展示非终态任务(排队/执行中/失败):状态图标、文件名、进度、取消/重试;
/// 顶部"全部取消"。终态反馈在历史页(完成自动入库)。
class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskQueueControllerProvider);
    final active = state.tasks.where((t) => !t.state.isFinal).toList();
    final runningCount = state.running.length;
    final queuedCount = active.where((t) => t.state == TaskState.queued).length;
    final failedCount = active.where((t) => t.state == TaskState.failed).length;
    final controller = ref.read(taskQueueControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务队列'),
        actions: [
          IconButton(
            tooltip: '全部取消',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: active.isEmpty ? null : () => controller.cancelAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '执行中 $runningCount · 排队 $queuedCount'
                  '${failedCount > 0 ? ' · 失败 $failedCount' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: active.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text('暂无进行中的任务'),
                        const SizedBox(height: 4),
                        Text(
                          '批量导入或重转的任务会出现在这里',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: active.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        QueueTaskListItem(task: active[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

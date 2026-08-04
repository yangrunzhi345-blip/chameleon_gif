import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../domain/value_objects/task_state.dart';
import '../application/task_queue_providers.dart';

/// 任务队列页(P6,docs/09 §9.5 状态流"TaskQueueState → 任务列表")。
///
/// 展示非终态任务(排队/执行中/失败);完整行(进度/取消/重试)与
/// 全部取消在 P6-WP2 落地,本版为壳(空态 + 状态行)。
class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskQueueControllerProvider);
    final active = state.tasks.where((t) => !t.state.isFinal).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('任务队列')),
      body: active.isEmpty
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
                  _QueueTaskRow(task: active[index]),
            ),
    );
  }
}

/// 队列行(占位渲染;进度/取消/重试在 P6-WP2 落地)。
class _QueueTaskRow extends StatelessWidget {
  const _QueueTaskRow({required this.task});

  final ExportTask task;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(
        task.videoPath.split(RegExp(r'[\\/]')).last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(task.state.name),
    );
  }
}

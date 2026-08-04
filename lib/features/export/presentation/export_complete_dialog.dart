import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_task.dart';
import '../application/export_providers.dart';

/// 导出完成弹窗(docs/10 §10.3.2):路径/大小/耗时 + [打开文件夹][再转一次][关闭]。
///
/// 数据由功能层注入(task + outputSizeBytes),UI 仅格式化展示与转发动作。
class ExportCompleteDialog extends ConsumerWidget {
  const ExportCompleteDialog({
    super.key,
    required this.task,
    required this.outputSizeBytes,
  });

  final ExportTask task;
  final int outputSizeBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = task.finishedAt?.difference(
      task.startedAt ?? task.createdAt,
    );
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('导出完成'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '文件:${task.outputPath ?? ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '大小:${formatFileSize(outputSizeBytes)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (elapsed != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '耗时:${formatHumanDuration(elapsed)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          // 动作转发到应用层用例(打开目录/路径提取均在功能层)
          onPressed: () =>
              ref.read(exportControllerProvider.notifier).openOutputFolder(),
          child: const Text('打开文件夹'),
        ),
        TextButton(
          onPressed: () {
            ref.read(exportControllerProvider.notifier).reset();
            Navigator.of(context).pop();
          },
          child: const Text('再转一次'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(exportControllerProvider.notifier).reset();
            Navigator.of(context).pop();
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

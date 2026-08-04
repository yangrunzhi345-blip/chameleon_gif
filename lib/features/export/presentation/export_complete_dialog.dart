import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_task.dart';
import '../../../shared/platform/platform_adapter.dart';
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
            '大小:${_formatSize(outputSizeBytes)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (elapsed != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '耗时:${_formatDuration(elapsed)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            final path = task.outputPath;
            if (path != null) {
              PlatformAdapter().openFolder(
                path.substring(0, path.lastIndexOf('/')),
              );
            }
          },
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    return s < 60 ? '$s 秒' : '${s ~/ 60} 分 ${s % 60} 秒';
  }
}

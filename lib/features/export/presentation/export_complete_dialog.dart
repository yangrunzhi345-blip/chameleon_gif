import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_task.dart';
import '../../../shared/platform/gallery_save_result.dart';
import '../application/export_providers.dart';

/// 导出完成弹窗(docs/10 §10.3.2):路径/大小/耗时 + 打开动作 + [再转一次][关闭]。
///
/// 数据由功能层注入(task + outputSizeBytes),UI 仅格式化展示与转发动作。
/// 相册三态:已保存 → 显示相册路径 + [打开相册];保存失败 → 保留文件行 +
/// 失败提示 + [分享];桌面(unsupported)→ 现状 [打开文件夹]。
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
    final saved = task.galleryStatus == GallerySaveStatus.saved;
    final failed = task.galleryStatus == GallerySaveStatus.failed;
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
          if (saved)
            Text(
              '已保存到系统相册:${task.galleryPath ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
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
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '未保存到相册:${task.galleryMessage ?? ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        // 动作转发到应用层用例(打开相册/目录/分享均在功能层)
        TextButton(
          onPressed: saved
              ? () => ref
                    .read(exportControllerProvider.notifier)
                    .openOutputFolder()
              : failed
              ? () => ref.read(exportControllerProvider.notifier).shareGif()
              : () => ref
                    .read(exportControllerProvider.notifier)
                    .openOutputFolder(),
          child: Text(saved ? '打开相册' : (failed ? '分享' : '打开文件夹')),
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

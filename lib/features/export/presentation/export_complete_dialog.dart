import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_task.dart';
import '../../../shared/platform/gallery_save_result.dart';

/// 完成弹窗动作集(宿主控制器绑定,消除对 exportControllerProvider 的
/// 硬编码 —— 图片制作 GIF 页面复用本弹窗,绑定自己的控制器)。
class ExportCompleteActions {
  const ExportCompleteActions({
    required this.onOpen,
    required this.onShare,
    required this.onReset,
  });

  /// 打开动作:saved → 打开相册;failed → 分享;unsupported → 打开文件夹。
  final Future<void> Function() onOpen;

  /// 系统分享(相册保存失败兜底)。
  final Future<void> Function() onShare;

  /// 弹窗关闭后回 idle,表单值保留(已保存相册的私有副本延迟删除)。
  final Future<void> Function() onReset;
}

/// 导出完成弹窗(docs/10 §10.3.2):路径/大小/耗时 + 打开动作 + [再转一次][关闭]。
///
/// 数据与动作均由宿主注入(task + outputSizeBytes + [ExportCompleteActions]),
/// UI 仅格式化展示与转发动作(视频预览页与图片制作页共用)。
/// 相册三态:已保存 → 显示相册路径 + [打开相册];保存失败 → 保留文件行 +
/// 失败提示 + [分享];桌面(unsupported)→ 现状 [打开文件夹]。
class ExportCompleteDialog extends StatelessWidget {
  const ExportCompleteDialog({
    super.key,
    required this.task,
    required this.outputSizeBytes,
    required this.actions,
  });

  final ExportTask task;
  final int outputSizeBytes;
  final ExportCompleteActions actions;

  @override
  Widget build(BuildContext context) {
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
        TextButton(
          onPressed: failed ? actions.onShare : actions.onOpen,
          child: Text(saved ? '打开相册' : (failed ? '分享' : '打开文件夹')),
        ),
        TextButton(
          onPressed: () {
            actions.onReset();
            Navigator.of(context).pop();
          },
          child: const Text('再转一次'),
        ),
        FilledButton(
          onPressed: () {
            actions.onReset();
            Navigator.of(context).pop();
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_history.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../application/history_controller.dart';
import '../application/history_providers.dart';

/// 历史详情对话框(docs/06 M05):参数快照/大小/耗时 + 重转/删除。
///
/// 动作转发到 [HistoryController](P5-WP3);解析失败关框后 SnackBar 中文文案。
class HistoryDetailDialog extends ConsumerWidget {
  const HistoryDetailDialog({super.key, required this.history});

  final ExportHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = history.settings;
    final controller = ref.read(historyControllerProvider.notifier);
    return AlertDialog(
      title: Text(
        history.videoPath.split(RegExp(r'[\\/]')).last,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(
              '完成时间',
              history.createdAt.toLocal().toString().substring(0, 19),
            ),
            _row(
              '源时长',
              formatHumanDuration(
                Duration(milliseconds: history.sourceDurationMs),
              ),
            ),
            _row('输出大小', formatFileSize(history.outputSizeBytes)),
            _row(
              '转码耗时',
              formatHumanDuration(Duration(milliseconds: history.durationMs)),
            ),
            if (history.outputFrameCount != null)
              _row('输出帧数', '${history.outputFrameCount}'),
            const Divider(),
            _row('帧率', '${s.fps} fps'),
            _row('宽度', s.width == 0 ? '原图等比' : '${s.width} px'),
            _row('循环', s.loop == 0 ? '无限' : '${s.loop} 次'),
            _row(
              '起止',
              '${formatFfmpegTime(s.start)} — '
                  '${formatFfmpegTime(s.end ?? Duration.zero)}',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            try {
              final id = await controller.retry(history);
              navigator.pop();
              if (id != null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('已开始重新转换')),
                );
              }
            } on FilePickException catch (e) {
              navigator.pop();
              messenger.showSnackBar(SnackBar(content: Text(e.userMessage)));
            }
          },
          child: const Text('重转'),
        ),
        TextButton(
          onPressed: () => _confirmDelete(context, controller),
          child: const Text('删除'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, HistoryController controller) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除该历史记录?'),
        content: const Text('仅删除记录,不影响已生成的 GIF 文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop(); // 关闭详情框
              controller.delete(history.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

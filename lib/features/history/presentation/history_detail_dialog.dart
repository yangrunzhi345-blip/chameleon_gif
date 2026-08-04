import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_history.dart';

/// 历史详情对话框(docs/06 M05):参数快照/大小/耗时 + 动作(重转/删除 WP3 接线)。
///
/// 只读展示,动作按钮在 WP3 接入 history 控制器后启用。
class HistoryDetailDialog extends ConsumerWidget {
  const HistoryDetailDialog({super.key, required this.history});

  final ExportHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = history.settings;
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
              '${formatFfmpegTime(s.start)} — ${formatFfmpegTime(s.end ?? Duration.zero)}',
            ),
          ],
        ),
      ),
      actions: [
        // 重转/删除在 P5-WP3 接入(见 HistoryController)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
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

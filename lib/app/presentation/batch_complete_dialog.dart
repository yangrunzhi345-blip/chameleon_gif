import 'package:flutter/material.dart';

import '../application/batch_session_controller.dart';

/// 批量完成弹窗("所有的任务已经完成"+ 统计 + 四去向)。
///
/// 动作转发由宿主注入:返回批量导入(恢复初始)/ 返回单独导入mp4 /
/// 返回首页 / 预览完成 GIF(无可预览输出时禁用)。
class BatchCompleteDialog extends StatelessWidget {
  const BatchCompleteDialog({
    super.key,
    required this.stats,
    required this.onBackToBatch,
    required this.onSingleImport,
    required this.onBackHome,
    required this.onPreview,
  });

  final BatchStats stats;
  final VoidCallback onBackToBatch;
  final VoidCallback onSingleImport;
  final VoidCallback onBackHome;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    // 统计文案:有失败/取消才追加对应段(取消任务不询问,此处体现)
    final summary = StringBuffer('成功 ${stats.completed} 个');
    if (stats.failed > 0) summary.write(' · 失败 ${stats.failed} 个');
    if (stats.cancelled > 0) summary.write(' · 取消 ${stats.cancelled} 个');
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('所有的任务已经完成'),
        ],
      ),
      content: Text(summary.toString()),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton(onPressed: onBackToBatch, child: const Text('返回批量导入')),
            TextButton(
              onPressed: onSingleImport,
              child: const Text('返回单独导入mp4'),
            ),
            TextButton(onPressed: onBackHome, child: const Text('返回首页')),
            FilledButton(
              onPressed: stats.completedGifPaths.isEmpty ? null : onPreview,
              child: const Text('预览'),
            ),
          ],
        ),
      ],
    );
  }
}

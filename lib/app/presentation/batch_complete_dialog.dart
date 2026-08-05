import 'package:flutter/material.dart';

import '../application/batch_session_controller.dart';

/// 批量完成弹窗("所有的任务已经完成"+ 统计 + 打开文件夹 + 三去向)。
///
/// 动作转发由宿主注入:打开文件夹(打开第一个成功输出所在目录,弹窗
/// 保持打开)/ 返回批量导入(恢复初始)/ 返回单独导入mp4 / 返回首页。
class BatchCompleteDialog extends StatelessWidget {
  const BatchCompleteDialog({
    super.key,
    required this.stats,
    required this.onOpenFolder,
    required this.onBackToBatch,
    required this.onSingleImport,
    required this.onBackHome,
  });

  final BatchStats stats;
  final VoidCallback onOpenFolder;
  final VoidCallback onBackToBatch;
  final VoidCallback onSingleImport;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    // 统计文案:有失败/取消才追加对应段(取消任务不询问,此处体现);
    // 相册保存状态仅在有失败项时提示(全成功时"成功 N 个"已含语义)
    final summary = StringBuffer('成功 ${stats.completed} 个');
    if (stats.failed > 0) summary.write(' · 失败 ${stats.failed} 个');
    if (stats.cancelled > 0) summary.write(' · 取消 ${stats.cancelled} 个');
    if (stats.gallerySaved > 0 && stats.completed == stats.gallerySaved) {
      summary.write('\n已保存到系统相册 ${stats.gallerySaved} 个');
    } else if (stats.galleryFailed > 0) {
      summary.write(
        '\n${stats.gallerySaved} 个已入相册,${stats.galleryFailed} 个保存失败请用分享',
      );
    }
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
            TextButton(
              onPressed: stats.completedGifPaths.isEmpty ? null : onOpenFolder,
              child: Text(stats.firstGalleryUri != null ? '打开相册' : '打开文件夹'),
            ),
            TextButton(onPressed: onBackToBatch, child: const Text('返回批量导入')),
            TextButton(
              onPressed: onSingleImport,
              child: const Text('返回单独导入mp4'),
            ),
            TextButton(onPressed: onBackHome, child: const Text('返回首页')),
          ],
        ),
      ],
    );
  }
}

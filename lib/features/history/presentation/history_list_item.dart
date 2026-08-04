import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/export_history.dart';
import '../application/history_providers.dart';
import 'history_detail_dialog.dart';

/// 历史列表项(docs/10 §10.3.3):缩略图 + 文件名 + 时间 + 大小。
///
/// 缩略图经 [historyThumbnailProvider] 异步加载,失败/加载中一律图标降级;
/// 点击/长按 → 详情对话框。
class HistoryListItem extends ConsumerWidget {
  const HistoryListItem({super.key, required this.history});

  final ExportHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = history.videoPath.split(RegExp(r'[\\/]')).last;
    final subtitle =
        '${formatFileSize(history.outputSizeBytes)} · '
        '${formatHumanDuration(Duration(milliseconds: history.durationMs))}';

    return ListTile(
      leading: _Thumbnail(videoPath: history.videoPath),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => HistoryDetailDialog(history: history),
      ),
      onLongPress: () => showDialog<void>(
        context: context,
        builder: (_) => HistoryDetailDialog(history: history),
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.videoPath});

  final String videoPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(historyThumbnailProvider(videoPath));
    final bytes = thumb.value;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          bytes,
          width: 96,
          height: 54,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return const SizedBox(
      width: 96,
      height: 54,
      child: Icon(Icons.movie_outlined, size: 32),
    );
  }
}

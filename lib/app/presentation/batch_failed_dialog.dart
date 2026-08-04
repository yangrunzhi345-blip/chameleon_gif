import 'package:flutter/material.dart';

import '../application/batch_session_controller.dart';

/// 批量失败询问弹窗:列出失败项,询问是否重新开始。
///
/// 点"重新开始"仅重试失败项(已完成/取消的不动);点"否"进入最终完成
/// 弹窗。动作转发由宿主注入(UI 不触 provider 细节)。
class BatchFailedDialog extends StatelessWidget {
  const BatchFailedDialog({
    super.key,
    required this.items,
    required this.onDecline,
    required this.onRetry,
  });

  final List<BatchFailedItem> items;
  final VoidCallback onDecline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('部分任务失败'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('以下转换失败,是否重新开始失败的转换?'),
          const SizedBox(height: 12),
          // 失败项列表(限高可滚;AlertDialog content 做 intrinsic 测量,
          // 不能放 ListView,用 SingleChildScrollView + Column 规避)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, item) in items.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline, size: 20),
                      title: Text(
                        item.path.split(RegExp(r'[\\/]')).last,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: item.errorDetail == null
                          ? null
                          : Text(
                              item.errorDetail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: onDecline, child: const Text('否')),
        FilledButton(onPressed: onRetry, child: const Text('重新开始')),
      ],
    );
  }
}

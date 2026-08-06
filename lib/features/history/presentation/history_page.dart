import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/history_providers.dart';
import 'history_list_item.dart';

/// 历史列表页(P5-WP2,docs/10 §10.3.3):时间倒序列表 + 空态 + 清空。
///
/// 数据经 [historyControllerProvider](常驻,completed 自动刷新);
/// 清空二次确认;列表为空时清空按钮禁用。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('转换历史'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: async.value?.isNotEmpty ?? false
                ? () => _confirmClear(context, ref)
                : null,
          ),
        ],
      ),
      body: switch (async) {
        AsyncData(:final value) when value.isNotEmpty => ListView.separated(
          itemCount: value.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              HistoryListItem(history: value[index]),
        ),
        AsyncData() => _EmptyView(), // 空态
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    // 一次性守卫:连点清空会第二次 pop,弹掉历史页路由
    var tapped = false;
    void guard(VoidCallback action) {
      if (tapped) return;
      tapped = true;
      action();
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部历史?'),
        content: const Text('该操作不可撤销,仅删除记录,不影响已生成的 GIF 文件。'),
        actions: [
          TextButton(
            onPressed: () => guard(() => Navigator.of(dialogContext).pop()),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => guard(() {
              Navigator.of(dialogContext).pop();
              ref.read(historyControllerProvider.notifier).clear();
            }),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('暂无转换历史'),
          const SizedBox(height: 4),
          Text(
            '完成一次视频转换后,记录会自动出现在这里',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/export_providers.dart';

/// 导出进度面板(docs/10 §10.3.1:转换中替换导出按钮)。
///
/// 纯渲染:进度条 + 百分比 + 预估剩余 + 取消按钮;数据全部来自
/// [exportProgressProvider](200ms 节流)与 [exportControllerProvider]。
class ExportProgressPanel extends ConsumerWidget {
  const ExportProgressPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(exportProgressProvider).value;
    final percent = progress?.percent ?? 0.0;
    final remaining = progress?.remaining;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(value: percent, minHeight: 6),
              ),
              const SizedBox(width: 12),
              Text(
                '${(percent * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  remaining == null
                      ? '正在生成调色板…'
                      : '预计剩余 ${_formatDuration(remaining)}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(exportControllerProvider.notifier).cancelTask(),
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '$s 秒';
    final m = s ~/ 60;
    final r = s % 60;
    return '$m 分 $r 秒';
  }
}

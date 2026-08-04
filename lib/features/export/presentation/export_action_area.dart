import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/video_info.dart';
import '../application/export_providers.dart';
import '../application/export_state.dart';
import 'export_progress_panel.dart';

/// 导出操作区(docs/10 §10.3.1:空闲显示导出按钮,转换中替换为进度面板)。
///
/// 纯渲染与事件转发:按钮 → [ExportController.submit](表单装配);
/// 完成/失败弹窗由 app 层组合壳(PreviewScreen)生命周期处理,本组件不弹窗。
/// [enabled] 由壳下传(导出中 false → 按钮禁用)。
class ExportActionArea extends ConsumerWidget {
  const ExportActionArea({super.key, required this.video, this.enabled = true});

  final VideoInfo video;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportControllerProvider);
    switch (state.lifecycle) {
      case ExportLifecycle.idle:
      case ExportLifecycle.done:
      case ExportLifecycle.failed:
        final blocked = !enabled || state.formError != null;
        return FilledButton.icon(
          onPressed: blocked
              ? null
              : () => ref
                    .read(exportControllerProvider.notifier)
                    .submit(video: video),
          icon: const Icon(Icons.gif),
          label: const Text('导出 GIF'),
        );
      case ExportLifecycle.exporting:
        return const ExportProgressPanel();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../application/export_providers.dart';
import '../application/export_state.dart';
import 'export_progress_panel.dart';

/// 导出操作区(docs/10 §10.3.1:空闲显示导出按钮,转换中替换为进度面板)。
///
/// 纯渲染与事件转发:按钮 → [ExportController.submit](默认参数);
/// 完成/失败弹窗由 PreviewPage 生命周期处理,本组件不弹窗。
class ExportBar extends ConsumerWidget {
  const ExportBar({super.key, required this.video});

  final VideoInfo video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportControllerProvider);
    switch (state.lifecycle) {
      case ExportLifecycle.idle:
      case ExportLifecycle.done:
      case ExportLifecycle.failed:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton.icon(
            onPressed: () => ref
                .read(exportControllerProvider.notifier)
                .submit(const GifSetting(), video),
            icon: const Icon(Icons.gif),
            label: const Text('导出 GIF(默认参数)'),
          ),
        );
      case ExportLifecycle.exporting:
        return const ExportProgressPanel();
    }
  }
}

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
/// [onBeforeSubmit] 为参数面板注入的"提交前 flush 文本字段"回调(返回
/// false = 有未解决表单错误,中止导出);无注入时直接导出。
class ExportActionArea extends ConsumerWidget {
  const ExportActionArea({
    super.key,
    required this.video,
    this.enabled = true,
    this.onBeforeSubmit,
  });

  final VideoInfo video;
  final bool enabled;

  /// 导出前回调(参数面板 flush 未回车的文本字段;false = 中止)。
  final bool Function()? onBeforeSubmit;

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
              : () {
                  // 先提交未回车的文本字段(循环/开始/结束);失败 → 中止
                  if (onBeforeSubmit?.call() == false) return;
                  ref
                      .read(exportControllerProvider.notifier)
                      .submit(video: video);
                },
          icon: const Icon(Icons.gif),
          label: const Text('导出 GIF'),
        );
      case ExportLifecycle.exporting:
        return const ExportProgressPanel();
    }
  }
}

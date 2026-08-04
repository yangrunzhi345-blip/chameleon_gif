import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/video_info.dart';
import '../../export/application/export_providers.dart';
import '../../export/application/export_state.dart';
import '../../export/presentation/export_bar.dart';
import '../../export/presentation/export_complete_dialog.dart';
import '../application/preview_providers.dart';
import 'preview_controls_bar.dart';
import 'video_preview_panel.dart';

/// 预览页(P2,docs/10-UI设计.md §10.3.1 预览区)。
///
/// 经路由 extra 接收 [VideoInfo];extra 为空(回退/深链)立即返回主页。
class PreviewPage extends ConsumerStatefulWidget {
  const PreviewPage({super.key, required this.video});

  final VideoInfo? video;

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  @override
  void initState() {
    super.initState();
    // 延迟到首帧后加载,避免 initState 内触发 Notifier 状态写入
    Future.microtask(() {
      if (!mounted) return;
      final video = widget.video;
      if (video == null) {
        context.pop();
        return;
      }
      ref.read(previewControllerProvider.notifier).load(video);
    });
    // 导出终态监听:完成 → 弹窗;失败/取消 → SnackBar(initState 场景用 listenManual)
    ref.listenManual<ExportUiState>(exportControllerProvider, (_, state) {
      if (!mounted) return;
      switch (state.lifecycle) {
        case ExportLifecycle.done:
          final task = state.task;
          if (task != null) {
            showDialog<void>(
              context: context,
              builder: (_) => ExportCompleteDialog(
                task: task,
                outputSizeBytes: state.outputSizeBytes ?? 0,
              ),
            );
          }
        case ExportLifecycle.failed:
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? '转换失败')),
            );
        case ExportLifecycle.idle:
        case ExportLifecycle.exporting:
          break;
      }
    }, fireImmediately: false);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(
        title: Text(video?.path.split('/').last ?? '预览'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Expanded(child: VideoPreviewPanel()),
          const SafeArea(child: PreviewControlsBar()),
          if (video != null) ExportBar(video: video),
        ],
      ),
    );
  }
}

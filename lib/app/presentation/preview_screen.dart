import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/video_info.dart';
import '../../features/export/application/export_providers.dart';
import '../../features/export/application/export_state.dart';
import '../../features/export/presentation/export_bar.dart';
import '../../features/export/presentation/export_complete_dialog.dart';
import '../../features/preview/application/preview_providers.dart';
import '../../features/preview/presentation/preview_controls_bar.dart';
import '../../features/preview/presentation/video_preview_panel.dart';

/// 预览页组合壳(app 层组装,§5.3 app→features 仅组装)。
///
/// 跨模块 UI 组合收敛于此:预览(preview 模块)+ 导出区(export 模块)互不
/// 依赖;壳只做组装与生命周期转发(load / 导出终态弹窗),无业务逻辑。
/// 经路由 extra 接收 [VideoInfo];extra 为空(回退/深链)立即返回主页。
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.video});

  final VideoInfo? video;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
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
    // 导出终态监听:完成 → 弹窗;失败/取消 → SnackBar(initState 用 listenManual)
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
        // Windows 反斜杠路径兼容(纯字符串处理,不触 IO)
        title: Text(
          video == null ? '预览' : video.path.split(RegExp(r'[\\/]')).last,
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show Player;
import 'package:media_kit_video/media_kit_video.dart';

import '../application/preview_controller.dart';
import '../application/preview_providers.dart';
import '../application/preview_state.dart';

/// 视频预览区(P2-WP2,docs/10-UI设计.md §10.3.1 预览区)。
///
/// 纯渲染:按 [PreviewState] 生命周期展示 加载态 / 错误视图 / 播放画面;
/// 播放器句柄经 [previewPlayerPortProvider] 的 renderHandle 桥接,
/// `is Player` 单点强转(widget 测试注入 Fake 时降级为占位,不触 FFI)。
class VideoPreviewPanel extends ConsumerStatefulWidget {
  const VideoPreviewPanel({super.key});

  @override
  ConsumerState<VideoPreviewPanel> createState() => _VideoPreviewPanelState();
}

class _VideoPreviewPanelState extends ConsumerState<VideoPreviewPanel> {
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    // 单点强转:renderHandle 是 Object 是 Domain 零依赖的代价;
    // 非 Player 分支(测试 Fake)渲染占位。VideoController 无需显式 dispose
    // (Video widget 经 player.release 清理监听,已查源码)。
    final handle = ref.read(previewPlayerPortProvider).renderHandle;
    if (handle is Player) {
      _videoController = VideoController(handle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewControllerProvider);
    switch (state.lifecycle) {
      case PreviewLifecycle.idle:
      case PreviewLifecycle.loading:
        return const Center(child: CircularProgressIndicator());
      case PreviewLifecycle.error:
        return _ErrorView(message: state.errorMessage);
      case PreviewLifecycle.ready:
        final controller = _videoController;
        if (controller == null) {
          return const SizedBox.expand(); // 测试环境降级
        }
        return Video(
          controller: controller,
          fit: BoxFit.fill,
          controls: NoVideoControls,
        );
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message ?? '视频播放失败'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}

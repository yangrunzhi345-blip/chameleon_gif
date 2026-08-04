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
    // 推迟到会话 ready 才构造 VideoController:死 Player 上构造必抛断言
    // (media_kit_video 构造函数内 fire-and-forget 异步 create)。
    // fireImmediately: 覆盖 panel 挂载时控制器已 ready 的边界;此时控制器
    // 必存活(本 panel 的 build watch 它),其 watch 保证端口必存活。
    // 单点强转:renderHandle 是 Object 是 Domain 零依赖的代价;
    // 非 Player 分支(测试 Fake)渲染占位。VideoController 无需显式 dispose
    // (Video widget 经 player.release 清理监听,已查源码)。
    // initState 场景用 listenManual(ref.listen 仅限 build 内,且无 fireImmediately)
    ref.listenManual<PreviewState>(previewControllerProvider, (_, state) {
      if (state.lifecycle == PreviewLifecycle.ready &&
          _videoController == null) {
        final handle = ref.read(previewPlayerPortProvider).renderHandle;
        if (handle is Player) {
          _videoController = VideoController(handle);
        }
      } else if (state.lifecycle == PreviewLifecycle.error) {
        _videoController = null; // 清残留:error 态不再渲染 Video
      }
    }, fireImmediately: true);
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

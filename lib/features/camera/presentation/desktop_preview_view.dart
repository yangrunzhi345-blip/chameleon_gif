import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 桌面相机流预览视图(media_kit 播放 ffmpeg UDP 推流;docs/18 里程碑 4)。
///
/// 纯渲染组件:URL 由 [desktopPreviewUrlProvider] 提供,本组件只负责
/// 播放器生命周期(创建/open/dispose)与渲染;录制切换由端口层维持
/// 同地址推流,播放器无需重连(短暂黑屏后恢复)。
class DesktopPreviewView extends StatefulWidget {
  const DesktopPreviewView({super.key, required this.url});

  /// 预览流地址(`udp://127.0.0.1:PORT?pkt_size=1316`)。
  final String url;

  @override
  State<DesktopPreviewView> createState() => _DesktopPreviewViewState();
}

class _DesktopPreviewViewState extends State<DesktopPreviewView> {
  VideoController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoController(Player());
      // UDP mpegts 自动探测(实测 mpv 无需格式提示);open 失败不抛
      await controller.player.open(Media(widget.url));
      if (!mounted) {
        controller.player.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      // 播放器不可用(测试宿主等):降级空渲染,不崩溃
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _failed) {
      // 播放器未就绪:黑底(与取景底一致),不显示错误打扰
      return const ColoredBox(color: Colors.black);
    }
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: BoxFit.cover,
    );
  }
}

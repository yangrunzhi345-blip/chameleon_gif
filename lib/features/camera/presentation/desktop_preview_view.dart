import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 桌面相机截帧预览视图(ffmpeg image2pipe JPEG 帧 → Image.memory;
/// docs/18 里程碑 4,方案 C 实测定案)。
///
/// 纯渲染组件:帧流由 [desktopPreviewFramesProvider] 提供,本组件只负责
/// 订阅最新帧与渲染;录制切换期间帧流关闭(设备独占),组件显示占位。
class DesktopPreviewView extends StatefulWidget {
  const DesktopPreviewView({super.key, required this.frames});

  /// JPEG 帧流(每帧完整 JPEG)。
  final Stream<Uint8List> frames;

  @override
  State<DesktopPreviewView> createState() => _DesktopPreviewViewState();
}

class _DesktopPreviewViewState extends State<DesktopPreviewView> {
  Uint8List? _latest;
  StreamSubscription<Uint8List>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.frames.listen(
      (frame) {
        if (mounted) setState(() => _latest = frame);
      },
      onError: (_) {}, // 帧流异常静默
      onDone: () {
        // 预览暂停(录制中设备独占):保留最后一帧冻结显示,
        // 避免黑屏(录制中仍有最后取景画面)
      },
    );
  }

  @override
  void didUpdateWidget(DesktopPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      // 预览会话重建(录制后恢复):重新订阅;保留旧帧直至新帧到达
      // (过渡期无黑屏)
      _sub?.cancel();
      _sub = widget.frames.listen(
        (frame) {
          if (mounted) setState(() => _latest = frame);
        },
        onError: (_) {},
        onDone: () {
          // 同上:冻结最后一帧
        },
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _latest;
    if (frame == null) {
      // 首帧未到/预览暂停:黑底(与取景底一致)
      return const ColoredBox(color: Colors.black);
    }
    return Image.memory(
      frame,
      fit: BoxFit.cover,
      gaplessPlayback: true, // 帧间无缝替换,避免闪烁
      filterQuality: FilterQuality.medium, // 放大平滑(低画质马赛克修复)
      // 坏帧容错:解码失败显示黑底,不中断预览(真实流偶发坏帧)
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
    );
  }
}

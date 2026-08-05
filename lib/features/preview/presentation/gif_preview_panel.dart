import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/gif_preview_controller.dart';
import '../application/preview_providers.dart';
import '../application/preview_state.dart';

/// GIF 帧渲染面板(纯渲染:消费 [GifPreviewController.frameStream] → RawImage)。
///
/// loading 态显示进度指示;error 态显示中文错误(隐藏"返回"由页面处理);
/// 帧流空(未开始)时渲染占位。
class GifPreviewPanel extends ConsumerWidget {
  const GifPreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gifPreviewControllerProvider);
    final controller = ref.read(gifPreviewControllerProvider.notifier);

    if (state.lifecycle == PreviewLifecycle.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.lifecycle == PreviewLifecycle.error) {
      return Center(
        child: Text(
          state.errorMessage ?? 'GIF 播放失败',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return StreamBuilder<ui.Image>(
      stream: controller.frameStream,
      builder: (context, snap) {
        final frame = snap.data;
        if (frame == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: RawImage(
            image: frame,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        );
      },
    );
  }
}

/// GIF 轻量控制条(播放/暂停 + 帧位置/总时长;GIF 循环播放无 seek 需求,
/// 与 MP4 预览的 [PreviewControlsBar](带进度条拖拽)保持独立)。
class GifControlsBar extends ConsumerWidget {
  const GifControlsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gifPreviewControllerProvider);
    final controller = ref.read(gifPreviewControllerProvider.notifier);
    final ready = state.lifecycle == PreviewLifecycle.ready;
    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      builder: (context, posSnap) => StreamBuilder<Duration>(
        stream: controller.durationStream,
        builder: (context, durSnap) {
          final pos = posSnap.data ?? Duration.zero;
          final dur = durSnap.data ?? Duration.zero;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: state.isPlaying ? '暂停' : '播放',
                iconSize: 36,
                icon: Icon(
                  state.isPlaying ? Icons.pause_circle : Icons.play_circle,
                ),
                onPressed: ready
                    ? () => state.isPlaying
                          ? controller.pause()
                          : controller.play()
                    : null,
              ),
              Text(
                '${_fmt(pos)} / ${_fmt(dur)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final total = d.inMilliseconds.round();
    final m = (total ~/ 60000).toString().padLeft(2, '0');
    final s = ((total % 60000) / 1000).toStringAsFixed(1).padLeft(4, '0');
    return '$m:$s';
  }
}

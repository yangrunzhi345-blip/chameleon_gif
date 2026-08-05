import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/preview_providers.dart';
import '../application/preview_state.dart';
import '../../../core/utils/duration_format.dart';

/// 预览控制条(P2-WP3,docs/10-UI设计.md 控制条 [播放]/[暂停]/进度)。
///
/// 纯渲染与事件转发:播放/暂停经 controller;进度经
/// [PreviewController.positionStream](200ms 节流)驱动,拖拽期本地
/// [ValueNotifier] 承载 UI 瞬态(docs/09-状态管理.md §9.6),onChangeEnd 才 seek。
class PreviewControlsBar extends ConsumerStatefulWidget {
  const PreviewControlsBar({super.key});

  @override
  ConsumerState<PreviewControlsBar> createState() => _PreviewControlsBarState();
}

class _PreviewControlsBarState extends ConsumerState<PreviewControlsBar> {
  final _dragValue = ValueNotifier<double>(0);
  bool _dragging = false;
  double _positionMs = 0;
  double _durationMs = 0;

  @override
  void dispose() {
    _dragValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(previewControllerProvider.notifier);
    final state = ref.watch(previewControllerProvider);
    final ready = state.lifecycle == PreviewLifecycle.ready;

    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      builder: (context, snap) {
        if (snap.hasData) _positionMs = snap.data!.inMilliseconds.toDouble();
        if (!_dragging) _dragValue.value = _positionMs;
        return StreamBuilder<Duration>(
          stream: controller.durationStream,
          builder: (context, durationSnap) {
            if (durationSnap.hasData) {
              _durationMs = durationSnap.data!.inMilliseconds.toDouble();
            }
            return Row(
              children: [
                IconButton(
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  icon: Icon(
                    state.isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 36,
                  ),
                  onPressed: ready
                      ? () => state.isPlaying
                            ? controller.pause()
                            : controller.play()
                      : null,
                ),
                Text(formatMmSs(_dragValue.value.round(), fractionDigits: 1)),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: _durationMs > 0 ? _durationMs : 1,
                    value: _dragValue.value.clamp(
                      0,
                      _durationMs > 0 ? _durationMs : 1,
                    ),
                    onChanged: ready
                        ? (v) {
                            _dragging = true;
                            _dragValue.value = v;
                          }
                        : null,
                    onChangeEnd: (v) {
                      _dragging = false;
                      controller.seekTo(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
                Text(formatMmSs(_durationMs.round(), fractionDigits: 1)),
                const SizedBox(width: 8),
              ],
            );
          },
        );
      },
    );
  }
}

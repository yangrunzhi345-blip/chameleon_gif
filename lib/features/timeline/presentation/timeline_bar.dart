import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/duration_format.dart';
import '../application/timeline_controller.dart';
import '../application/timeline_providers.dart';

/// 时间轴(P4-WP1,docs/10 §10.3.1):起止双句柄选区 + 播放头 + I/O 快捷键。
///
/// 纯渲染与事件转发:
/// - 拖动 tick → [TimelineController.setRange](节流 seek,不碰表单);
/// - 拖动结束 → [TimelineController.commitRange];
/// - `I`/`O` 设起点/终点(当前播放位置)、空格播放/暂停(仅本组件聚焦时);
/// - 播放头 = positionStream(200ms 节流)叠加于选区轨道,IgnorePointer 不干扰拖动。
class TimelineBar extends ConsumerStatefulWidget {
  const TimelineBar({super.key, this.enabled = true});

  /// 导出中禁用(壳下传,onChanged 置空)。
  final bool enabled;

  @override
  ConsumerState<TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends ConsumerState<TimelineBar> {
  final _dragValues = ValueNotifier<RangeValues?>(null);
  final _focusNode = FocusNode();
  double _positionMs = 0;
  double _durationMs = 0;

  /// 轨道内边距近似(默认 thumb 半径 + 内边距),播放头 x 对齐用,目测校准。
  static const _trackPad = 20.0;

  @override
  void dispose() {
    _dragValues.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = ref.read(timelineControllerProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyI:
        // I:当前播放位置设为起点(位置流 200ms 节流,滞后可接受)
        controller.commitRange(
          start: Duration(milliseconds: _positionMs.round()),
          end: ref.read(timelineControllerProvider).end,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyO:
        controller.commitRange(
          start: ref.read(timelineControllerProvider).start,
          end: Duration(milliseconds: _positionMs.round()),
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        // 播放/暂停经 TimelineController 转发(UI 不直依赖 preview 模块)
        controller.togglePlayPause();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineControllerProvider);
    final timelineController = ref.read(timelineControllerProvider.notifier);
    final ready = timelineController.previewReady;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: StreamBuilder<Duration>(
        stream: timelineController.positionStream,
        builder: (context, positionSnap) {
          if (positionSnap.hasData) {
            _positionMs = positionSnap.data!.inMilliseconds.toDouble();
          }
          return StreamBuilder<Duration>(
            stream: timelineController.durationStream,
            builder: (context, durationSnap) {
              if (durationSnap.hasData) {
                _durationMs = durationSnap.data!.inMilliseconds.toDouble();
              }
              final maxMs = _durationMs > 0 ? _durationMs : 1.0;
              final values =
                  _dragValues.value ??
                  RangeValues(
                    timeline.start.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxMs)
                        .toDouble(),
                    timeline.end.inMilliseconds
                        .toDouble()
                        .clamp(0.0, maxMs)
                        .toDouble(),
                  );
              final canDrag = widget.enabled && ready;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(formatMmSs(values.start.round(), fractionDigits: 1)),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    RangeSlider(
                                      min: 0,
                                      max: maxMs,
                                      values: values,
                                      labels: RangeLabels(
                                        formatMmSs(values.start.round(), fractionDigits: 1),
                                        formatMmSs(values.end.round(), fractionDigits: 1),
                                      ),
                                      onChanged: canDrag
                                          ? (v) {
                                              _dragValues.value = v;
                                              final moved =
                                                  (v.start - values.start)
                                                          .abs() >=
                                                      (v.end - values.end).abs()
                                                  ? v.start
                                                  : v.end;
                                              ref
                                                  .read(
                                                    timelineControllerProvider
                                                        .notifier,
                                                  )
                                                  .seekPreview(
                                                    Duration(
                                                      milliseconds: moved
                                                          .round(),
                                                    ),
                                                  );
                                              ref
                                                  .read(
                                                    timelineControllerProvider
                                                        .notifier,
                                                  )
                                                  .setRange(
                                                    start: Duration(
                                                      milliseconds: v.start
                                                          .round(),
                                                    ),
                                                    end: Duration(
                                                      milliseconds: v.end
                                                          .round(),
                                                    ),
                                                  );
                                            }
                                          : null,
                                      onChangeEnd: canDrag
                                          ? (v) {
                                              _dragValues.value = null;
                                              ref
                                                  .read(
                                                    timelineControllerProvider
                                                        .notifier,
                                                  )
                                                  .commitRange(
                                                    start: Duration(
                                                      milliseconds: v.start
                                                          .round(),
                                                    ),
                                                    end: Duration(
                                                      milliseconds: v.end
                                                          .round(),
                                                    ),
                                                  );
                                            }
                                          : null,
                                    ),
                                    // 播放头(不参与拖动;Positioned 须为 Stack 直接子级)
                                    Positioned(
                                      left:
                                          _trackPad +
                                          (_positionMs / maxMs)
                                                  .clamp(0.0, 1.0)
                                                  .toDouble() *
                                              (constraints.maxWidth -
                                                  2 * _trackPad),
                                      top: 6,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 2,
                                          height: 20,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        Text(formatMmSs(values.end.round(), fractionDigits: 1)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '选区 ${formatFfmpegTime(timeline.start).substring(3)} — '
                          '${formatFfmpegTime(timeline.end).substring(3)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          'I 设起点 · O 设终点 · 空格播放',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

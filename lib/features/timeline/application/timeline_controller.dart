import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_math.dart';
import '../../preview/application/preview_controller.dart';
import '../../preview/application/preview_providers.dart';
import 'range_selection.dart';

/// 时间轴控制器(docs/06 §6.2 M03,§9.2 层次二,autoDispose)。
///
/// 起止选区交互状态机:
/// - [init]:会话初始化(视频时长 + 表单初始起止),钳制到 [0, duration];
/// - [setRange]:拖动 tick,更新选区并**节流 seek 预览**(不联动表单);
/// - [commitRange]:拖动结束 / I/O 快捷键,更新选区 + 联动导出表单(syncRange);
/// - [setStart]/[setEnd]:表单侧回写,钳制 + 自动交换 + 联动表单。
///
/// 跨模块协作经应用层 controller(ref.read,§9.7):seek 走
/// [PreviewController.seekTo],表单镜像走 [ExportController.syncRange];
/// 本控制器不 watch 两者(视频时长由壳注入,避免重建重置选区)。
class TimelineController extends Notifier<RangeSelection> {
  Duration? _videoDuration;
  Timer? _seekTimer;

  @override
  RangeSelection build() {
    ref.onDispose(() => _seekTimer?.cancel());
    return const RangeSelection(start: Duration.zero, end: Duration.zero);
  }

  /// 会话初始化(壳在预览 ready 后调用;start/end 取表单当前值)。
  void init({
    required Duration videoDuration,
    Duration start = Duration.zero,
    Duration? end,
  }) {
    _videoDuration = videoDuration;
    final clampedStart = _clampToVideo(start);
    final clampedEnd = _clampToVideo(end ?? videoDuration);
    final (s, e) = normalizeRange(clampedStart, clampedEnd);
    state = RangeSelection(start: s, end: e);
  }

  /// 拖动 tick:更新选区(钳制+交换)+ 节流 seek 拖动手柄,不联动表单。
  void setRange({required Duration start, required Duration end}) {
    final (s, e) = _normalized(start, end);
    state = RangeSelection(start: s, end: e);
  }

  /// 拖动结束 / I/O 快捷键:更新选区。
  ///
  /// 联动导出表单(syncRange)在 WP3 接线提交接入,见
  /// [ExportController.syncRange]。
  void commitRange({required Duration start, required Duration end}) {
    final (s, e) = _normalized(start, end);
    state = RangeSelection(start: s, end: e);
  }

  /// 表单回写起点(钳制 + 交换 + 联动表单,幂等)。
  void setStart(Duration d) => commitRange(start: d, end: state.end);

  /// 表单回写终点(钳制 + 交换 + 联动表单,幂等)。
  void setEnd(Duration d) => commitRange(start: state.start, end: d);

  /// 拖动中实时 seek,尾缘 100ms 节流(末次发射后才执行;
  /// onChangeEnd 前调用 [cancelPendingSeek] 防双 seek)。
  void seekPreview(Duration position) {
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 100), () {
      ref.read(previewControllerProvider.notifier).seekTo(position);
    });
  }

  /// 拖动结束取消未决 seek(避免 onChangeEnd 后再次跳转)。
  void cancelPendingSeek() {
    _seekTimer?.cancel();
    _seekTimer = null;
  }

  (Duration, Duration) _normalized(Duration start, Duration end) {
    return normalizeRange(_clampToVideo(start), _clampToVideo(end));
  }

  Duration _clampToVideo(Duration d) {
    final max = _videoDuration ?? Duration.zero;
    if (d < Duration.zero) return Duration.zero;
    if (d > max) return max;
    return d;
  }
}

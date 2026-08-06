import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../preview/application/preview_providers.dart';
import '../../preview/application/preview_state.dart';
import 'range_selection.dart';
import 'timeline_controller.dart';

/// 时间轴会话状态(docs/09 §9.2 层次二,autoDispose)。
final timelineControllerProvider =
    NotifierProvider.autoDispose<TimelineController, RangeSelection>(
      TimelineController.new,
    );

/// 预览就绪门控(timeline 侧响应式消费)。
///
/// 跨模块协作收敛在 application 层(timeline → preview 为批准模式,与
/// [TimelineController] 同源);UI(timeline_bar)禁止跨模块 import preview,
/// 经本派生 provider watch —— 就绪迁移必须触发时间轴重建以激活滑块
/// (回归 0376c13:read 快照只通知兄弟节点,滑块永远禁用)。
final timelinePreviewReadyProvider = Provider<bool>(
  (ref) =>
      ref.watch(previewControllerProvider).lifecycle == PreviewLifecycle.ready,
);

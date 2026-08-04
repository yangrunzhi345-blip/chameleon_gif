import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'range_selection.dart';
import 'timeline_controller.dart';

/// 时间轴会话状态(docs/09 §9.2 层次二,autoDispose)。
final timelineControllerProvider =
    NotifierProvider.autoDispose<TimelineController, RangeSelection>(
      TimelineController.new,
    );

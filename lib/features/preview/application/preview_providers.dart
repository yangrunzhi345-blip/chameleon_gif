import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_controller.dart';
import 'preview_state.dart';

/// 预览会话状态(docs/09-状态管理.md §9.2 层次二,autoDispose)。
/// 未被监听即销毁,`ref.onDispose` 内取消订阅并 dispose 播放器(R-06,
/// 与 [previewPlayerPortProvider](preview_controller.dart) 的 onDispose
/// 双路径幂等释放);端口随本控制器销毁后重建,不复用已销毁的 Player。
final previewControllerProvider =
    NotifierProvider.autoDispose<PreviewController, PreviewState>(
      PreviewController.new,
    );

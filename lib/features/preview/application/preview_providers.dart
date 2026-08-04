import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_controller.dart';
import 'preview_state.dart';

/// 预览会话状态(docs/09-状态管理.md §9.2 层次二,autoDispose)。
/// 未被监听即销毁,`ref.onDispose` 内释放播放器(R-06)。
/// 播放器端口见 [previewPlayerPortProvider](preview_controller.dart)。
final previewControllerProvider =
    NotifierProvider.autoDispose<PreviewController, PreviewState>(
      PreviewController.new,
    );

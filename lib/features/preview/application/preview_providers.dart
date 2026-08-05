import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gif_preview_controller.dart';
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

/// GIF 逐帧预览状态(完成 GIF 预览专用,autoDispose)。
/// Android 上 media_kit(mpv)无法播放 GIF(实证,见 gif_preview_controller.dart),
/// GIF 走 image 包逐帧解码,MP4 预览不受影响。
final gifPreviewControllerProvider =
    NotifierProvider.autoDispose<GifPreviewController, PreviewState>(
      GifPreviewController.new,
    );

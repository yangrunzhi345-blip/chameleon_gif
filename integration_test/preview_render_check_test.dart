import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 预览渲染冒烟(P7 黑屏 bug 回归,需桌面环境):
///   flutter test -d linux integration_test/preview_render_check_test.dart
///
/// 真实 mpv + Flutter 纹理渲染,断言 **首帧渲染完成**
/// ([VideoController.waitUntilFirstFrameRendered] 由 mpv 回传视频尺寸
/// 触发;media_kit_video 的黑色遮挡层在 rect>1 前覆盖纹理——超时即黑屏)。
///
/// 背景(docs/17 已知问题):X11/XWayland 下 EGL context 不可用,
/// media_kit H/W 路径失败 → 默认配置黑屏(有声音无画面);本文件强制
/// 软件渲染路径(`enableHardwareAcceleration: false` + `hwdec: 'no'`)。
/// 对照组(原生 Wayland 会话):`GDK_BACKEND=wayland flutter test -d linux
/// integration_test/preview_render_check_test.dart`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  const sample = 'test/fixtures/videos/chameleon.mp4'; // 720p 真实素材

  testWidgets('修复时序:VideoController 先于 open 创建 → 首帧渲染', (tester) async {
    final player = Player();
    addTearDown(player.dispose);

    // 修复后时序(与 video_preview_panel initState 一致):先创建
    // VideoController,后 open——media_kit_video 2.0.1 反向时序黑屏
    final controller = VideoController(player);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Video(controller: controller)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await player.open(Media('${Directory.current.path}/$sample'));
    await player.play();

    // 关键断言:等待**真实视频尺寸**回传(rect > 1 = mpv 实际输出视频帧,
    // media_kit_video 的黑色遮挡层据此移除)。注意 waitUntilFirstFrameRendered
    // 在占位纹理(1x1)阶段即完成,不能单独作为"画面出现"的证据(假阳性)。
    var rendered = false;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      final r = controller.rect.value;
      if (r != null && r.width > 1 && r.height > 1) {
        rendered = true;
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    debugPrint(
      'render 结果: rendered=$rendered '
      'id=${controller.id.value} rect=${controller.rect.value}',
    );
    expect(rendered, isTrue, reason: '真实视频尺寸应回传(超时 = 黑屏)');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/features/preview/application/preview_controller.dart';
import 'package:gif_forge/features/preview/application/preview_providers.dart';
import 'package:gif_forge/features/preview/presentation/video_preview_panel.dart';

import '../../fixtures/fake_player_port.dart';

/// [VideoPreviewPanel] 生命周期渲染测试(注入 Fake,renderHandle 非 Player
/// 时降级占位,不触 FFI)。
void main() {
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mov,mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  late FakePlayerPort port;

  Widget wrap() {
    return ProviderScope(
      overrides: [previewPlayerPortProvider.overrideWithValue(port)],
      child: const MaterialApp(home: Scaffold(body: VideoPreviewPanel())),
    );
  }

  setUp(() {
    port = FakePlayerPort();
  });

  testWidgets('初始 idle 态显示加载指示器(空态/加载态)', (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error 态显示错误文案与返回按钮', (tester) async {
    await tester.pumpWidget(wrap());
    port.openError = StateError('boom');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VideoPreviewPanel)),
    );
    await container.read(previewControllerProvider.notifier).load(video);
    await tester.pump();

    expect(find.text('视频加载失败,请尝试其他文件'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
  });
}

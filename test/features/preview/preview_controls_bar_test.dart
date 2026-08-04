import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/preview/presentation/preview_controls_bar.dart';

import '../../fixtures/fake_player_port.dart';

/// [PreviewControlsBar] 交互测试(注入 Fake):播放/暂停转发、进度更新、
/// 拖拽结束才 seek(UI 瞬态不污染功能层)。
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
      child: const MaterialApp(home: Scaffold(body: PreviewControlsBar())),
    );
  }

  Future<void> loadAndReady(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PreviewControlsBar)),
    );
    await container.read(previewControllerProvider.notifier).load(video);
    await tester.pump();
    await tester.pump(); // 等 stream 事件派发
  }

  setUp(() {
    port = FakePlayerPort();
  });

  testWidgets('ready 后点暂停 → pauseCount +1,icon 切换', (tester) async {
    await loadAndReady(tester);

    await tester.tap(find.byIcon(Icons.pause_circle));
    await tester.pump();
    expect(port.pauseCount, 1);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
  });

  testWidgets('position 流更新进度显示', (tester) async {
    await loadAndReady(tester);

    port.emitPosition(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 节流窗口过后

    expect(find.textContaining('00:03.0'), findsOneWidget);
  });

  testWidgets('拖动 Slider 结束才 seek(seekCalls 记录目标值)', (tester) async {
    await loadAndReady(tester);
    port.emitDuration(const Duration(seconds: 10));
    await tester.pump();

    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(120, 0));
    await tester.pump();

    expect(port.seekCalls, isNotEmpty);
    final seekTarget = port.seekCalls.last;
    expect(seekTarget.inMilliseconds, greaterThan(0));
  });
}

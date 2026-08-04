import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/features/preview/application/preview_controller.dart';
import 'package:gif_forge/features/preview/application/preview_providers.dart';
import 'package:gif_forge/features/timeline/application/timeline_providers.dart';
import 'package:gif_forge/features/timeline/presentation/timeline_bar.dart';

import '../../fixtures/fake_player_port.dart';

/// [TimelineBar] 交互测试(参照 preview_controls_bar_test 拖动模式)。
void main() {
  late FakePlayerPort port;

  Widget wrap({bool enabled = true}) {
    return ProviderScope(
      overrides: [previewPlayerPortProvider.overrideWithValue(port)],
      child: MaterialApp(
        home: Scaffold(body: TimelineBar(enabled: enabled)),
      ),
    );
  }

  Future<void> readyAndInit(WidgetTester tester) async {
    port = FakePlayerPort();
    await tester.pumpWidget(wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    container
        .read(timelineControllerProvider.notifier)
        .init(
          videoDuration: const Duration(seconds: 10),
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 8),
        );
    // 加载预览进入 ready(position/duration 流有数据)
    await container
        .read(previewControllerProvider.notifier)
        .load(
          const VideoInfo(
            path: '/tmp/videos/demo.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('渲染选区文本与快捷键提示', (tester) async {
    await readyAndInit(tester);

    expect(find.textContaining('00:02.0'), findsWidgets);
    expect(find.textContaining('I 设起点'), findsOneWidget);
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('拖动右句柄 → commitRange 更新选区并 seek', (tester) async {
    await readyAndInit(tester);

    final slider = find.byType(RangeSlider);
    // 从右 3/4 处向左拖(改 end)
    await tester.dragFrom(
      tester.getTopLeft(slider) +
          Offset(tester.getSize(slider).width * 0.75, 12),
      const Offset(-80, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    final sel = container.read(timelineControllerProvider);
    expect(sel.end, lessThan(const Duration(seconds: 8)), reason: 'end 被拖小');
    expect(port.seekCalls, isNotEmpty, reason: '拖动中节流 seek 已触发');
  });

  testWidgets('I/O 快捷键设起点/终点(当前播放位置)', (tester) async {
    await readyAndInit(tester);

    // 定位到 5s
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    port.emitPosition(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250)); // 位置流节流窗口

    // 聚焦时间轴后按 I
    await tester.tap(find.byType(TimelineBar));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(
      container.read(timelineControllerProvider).start,
      const Duration(seconds: 5),
    );
  });

  testWidgets('空格切换播放/暂停', (tester) async {
    await readyAndInit(tester);

    await tester.tap(find.byType(TimelineBar));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(port.pauseCount, 1, reason: '播放中按空格应暂停');
  });

  testWidgets('enabled=false 时 RangeSlider 禁用', (tester) async {
    port = FakePlayerPort();
    await tester.pumpWidget(wrap(enabled: false));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TimelineBar)),
    );
    container
        .read(timelineControllerProvider.notifier)
        .init(videoDuration: const Duration(seconds: 10));

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.onChanged, isNull);
  });
}

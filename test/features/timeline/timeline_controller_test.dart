import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/features/preview/application/preview_controller.dart';
import 'package:gif_forge/features/timeline/application/range_selection.dart';
import 'package:gif_forge/features/timeline/application/timeline_controller.dart';
import 'package:gif_forge/features/timeline/application/timeline_providers.dart';

import '../../fixtures/fake_player_port.dart';

/// [TimelineController] 状态机测试(docs/14 §14.3 时间轴用例)。
void main() {
  late ProviderContainer container;
  late FakePlayerPort port;

  ProviderContainer buildContainer() {
    port = FakePlayerPort();
    return ProviderContainer(
      overrides: [previewPlayerPortProvider.overrideWithValue(port)],
    )..listen(timelineControllerProvider, (_, _) {});
  }

  tearDown(() {
    container.dispose();
  });

  TimelineController ctl() =>
      container.read(timelineControllerProvider.notifier);

  RangeSelection sel() => container.read(timelineControllerProvider);

  const tenSec = Duration(seconds: 10);

  test('init:end 缺省取视频时长;自定义 start/end 生效', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    expect(sel().start, Duration.zero);
    expect(sel().end, tenSec);

    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 6),
    );
    expect(sel().start, const Duration(seconds: 2));
    expect(sel().end, const Duration(seconds: 6));
  });

  test('init:超界值钳制到 [0, 视频时长]', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: -1),
      end: const Duration(seconds: 99),
    );
    expect(sel().start, Duration.zero);
    expect(sel().end, tenSec);
  });

  test('init:start > end 自动交换', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 8),
      end: const Duration(seconds: 3),
    );
    expect(sel().start, const Duration(seconds: 3));
    expect(sel().end, const Duration(seconds: 8));
  });

  test('setRange:更新选区并钳制,不触发表单联动', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().setRange(
      start: const Duration(seconds: 3),
      end: const Duration(seconds: 9),
    );
    expect(sel().start, const Duration(seconds: 3));
    expect(sel().end, const Duration(seconds: 9));

    // 越界钳制
    ctl().setRange(
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 99),
    );
    expect(sel().end, tenSec);
  });

  test('commitRange:落选区;setStart/setEnd 交换后更新', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().commitRange(
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 7),
    );
    expect(sel().start, const Duration(seconds: 2));

    // 把起点设到终点之后 → 自动交换
    ctl().setStart(const Duration(seconds: 8));
    expect(sel().start, const Duration(seconds: 7));
    expect(sel().end, const Duration(seconds: 8));
  });

  test('seekPreview:尾缘 100ms 节流,连发只执行末次', () async {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().seekPreview(const Duration(seconds: 1));
    ctl().seekPreview(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(port.seekCalls, isEmpty, reason: '窗口内不 seek');

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(port.seekCalls, [const Duration(seconds: 2)], reason: '尾缘执行末次');
  });

  test('cancelPendingSeek:拖动结束取消未决 seek', () async {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().seekPreview(const Duration(seconds: 3));
    ctl().cancelPendingSeek();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(port.seekCalls, isEmpty, reason: '未决 seek 已取消');
  });

  test('重新 init(换视频)选区重置', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 5),
    );
    ctl().init(
      videoDuration: const Duration(seconds: 3),
      start: const Duration(seconds: 1),
    );
    expect(sel().start, const Duration(seconds: 1));
    expect(sel().end, const Duration(seconds: 3));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_state.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_player_port.dart';

/// [PreviewController] 状态机与生命周期测试(注入 [FakePlayerPort],纯 Dart)。
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
  late ProviderContainer container;

  ProviderContainer buildContainer(FakePlayerPort p) {
    final container = ProviderContainer(
      // 端口释放经控制器 onDispose 路径(双路径中先行者);overrideWithValue
      // 不执行 create 闭包,不会注册端口自身的 onDispose,不影响本测试组。
      overrides: [
        previewPlayerPortProvider.overrideWithValue(p),
        // load 失败路径记日志(appLoggerProvider 为 UnimplementedError 占位)
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
    );
    // 保持 autoDispose provider 存活:纯 read 不建立 watcher,空闲期会被
    // Riverpod GC 重建(异步 load 期间销毁导致断言读到新 idle 实例)。
    // listen 的语义与真实 UI 的 watch 一致。
    container.listen(previewControllerProvider, (_, _) {});
    return container;
  }

  tearDown(() {
    container.dispose();
  });

  test('load: idle → loading → ready(打开即播放)', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);

    expect(
      container.read(previewControllerProvider).lifecycle,
      PreviewLifecycle.idle,
    );

    await controller.load(video);

    expect(port.openedPath, video.path);
    expect(
      container.read(previewControllerProvider).lifecycle,
      PreviewLifecycle.ready,
    );
    expect(container.read(previewControllerProvider).isPlaying, isTrue);
  });

  test('open 抛错 → error 态 + GIF_PLAY_OPEN_FAILED', () async {
    port = FakePlayerPort();
    port.openError = StateError('open failed');
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);

    await controller.load(video);

    final state = container.read(previewControllerProvider);
    expect(state.lifecycle, PreviewLifecycle.error);
    expect(state.errorCode, 'GIF_PLAY_OPEN_FAILED');
  });

  test('play/pause/seekTo 转发到端口', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    await controller.load(video);

    controller.pause();
    await pumpEventQueue();
    expect(port.pauseCount, 1);
    expect(container.read(previewControllerProvider).isPlaying, isFalse);

    controller.play();
    await pumpEventQueue();
    expect(port.playCount, 1);
    expect(container.read(previewControllerProvider).isPlaying, isTrue);

    await controller.seekTo(const Duration(seconds: 3));
    expect(port.seekCalls, [const Duration(seconds: 3)]);
  });

  test('playingStream 发射 → state.isPlaying 更新', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    await controller.load(video);

    port.emitPlaying(false);
    await pumpEventQueue();
    expect(container.read(previewControllerProvider).isPlaying, isFalse);
  });

  test('errorStream 发射 → error 态 + GIF_PLAY_FAILED', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    await controller.load(video);

    port.emitError('mpv error');
    await pumpEventQueue();
    final state = container.read(previewControllerProvider);
    expect(state.lifecycle, PreviewLifecycle.error);
    expect(state.errorCode, 'GIF_PLAY_FAILED');
  });

  test('completedStream 发射 → isCompleted 更新', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    await controller.load(video);

    port.emitCompleted(true);
    await pumpEventQueue();
    expect(container.read(previewControllerProvider).isCompleted, isTrue);
  });

  test('容器销毁 → 播放器 dispose(泄漏回归,R-06)', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    container.read(previewControllerProvider.notifier).load(video);

    container.dispose();
    expect(port.disposed, isTrue);
  });

  test('会话结束 → 端口释放;新会话重建全新端口(连续导入回归)', () async {
    final ports = <FakePlayerPort>[];
    final container = ProviderContainer(
      overrides: [
        previewPlayerPortProvider.overrideWith((ref) {
          final p = FakePlayerPort();
          ports.add(p);
          ref.onDispose(() => p.dispose());
          return p;
        }),
      ],
    );
    addTearDown(container.dispose);

    // 会话 A:打开 → 就绪
    final subA = container.listen(previewControllerProvider, (_, _) {});
    final ctlA = container.read(previewControllerProvider.notifier);
    await ctlA.load(video);
    expect(
      container.read(previewControllerProvider).lifecycle,
      PreviewLifecycle.ready,
    );
    final portA = ports.single;

    // 模拟离开预览页:取消最后一个监听者 → autoDispose 调度销毁(零时长 Timer)
    subA.close();
    await pumpEventQueue();
    expect(portA.disposed, isTrue, reason: '会话 A 结束端口必须释放');

    // 会话 B:销毁后重建,create 重新求值 → 全新端口,加载成功
    final subB = container.listen(previewControllerProvider, (_, _) {});
    final ctlB = container.read(previewControllerProvider.notifier);
    final portB = ports.last;
    expect(identical(portB, portA), isFalse, reason: '新会话必须重建全新端口');
    await ctlB.load(video);
    expect(
      container.read(previewControllerProvider).lifecycle,
      PreviewLifecycle.ready,
    );
    expect(portB.openedPath, video.path);

    subB.close();
    await pumpEventQueue();
    expect(portB.disposed, isTrue);
  });

  test('load 中途容器销毁 → 不抛异常(竞态防护)', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    final future = controller.load(video);

    container.dispose();
    await future; // 不应抛出
  });

  test('positionStream 200ms 节流:窗口内多发事件收敛并取尾缘', () async {
    port = FakePlayerPort();
    container = buildContainer(port);
    final controller = container.read(previewControllerProvider.notifier);
    await controller.load(video);

    final collected = <Duration>[];
    final sub = controller.positionStream.listen(collected.add);

    port.emitPosition(const Duration(seconds: 1));
    port.emitPosition(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(collected, isEmpty, reason: '200ms 窗口内不应发射');

    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(collected, [const Duration(seconds: 2)], reason: '尾缘合并为最新值');

    await sub.cancel();
  });
}

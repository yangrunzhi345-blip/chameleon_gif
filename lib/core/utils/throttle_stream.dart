import 'dart:async';

/// 节流(尾缘):末次发射后 [minInterval] 内的新事件合并为一次,期间最新值
/// 在窗口结束时统一发出。适合 position 等高刷流 → UI 进度(200ms,见
/// docs/09-状态管理.md §9.3 与 docs/12 P7-WP1)。
Stream<T> throttleStream<T>(Stream<T> source, Duration minInterval) {
  late final StreamController<T> controller;
  Timer? timer;
  T? pending;
  var hasPending = false;
  // 源订阅(P7 修复):不保存则取消时只停定时器,源(broadcast 常驻流如
  // media_kit position / TaskManager progress)上的监听永不回收,每次
  // 预览/导出交互累积一条常驻监听 + 定时唤醒(内存/CPU 持续增长)。
  StreamSubscription<T>? sourceSub;

  void flush() {
    timer = null;
    if (hasPending) {
      hasPending = false;
      controller.add(pending as T);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      sourceSub = source.listen(
        (event) {
          pending = event;
          hasPending = true;
          timer ??= Timer(minInterval, flush);
        },
        onError: controller.addError,
        onDone: () {
          if (timer != null) {
            timer!.cancel();
            timer = null;
          }
          if (hasPending) {
            hasPending = false;
            controller.add(pending as T);
          }
          controller.close();
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
      // 取消源订阅(与取消定时器配对),未发射的尾缘事件一并丢弃
      sourceSub?.cancel();
      sourceSub = null;
      hasPending = false;
    },
  );
  return controller.stream;
}

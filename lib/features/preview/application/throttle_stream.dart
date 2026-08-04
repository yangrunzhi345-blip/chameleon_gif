import 'dart:async';

/// 节流(尾缘):末次发射后 [minInterval] 内的新事件合并为一次,期间最新值
/// 在窗口结束时统一发出。适合 position 等高刷流 → UI 进度(200ms,见
/// docs/09-状态管理.md §9.3 与 docs/12 P7-WP1)。
Stream<T> throttleStream<T>(Stream<T> source, Duration minInterval) {
  late final StreamController<T> controller;
  Timer? timer;
  T? pending;
  var hasPending = false;

  void flush() {
    timer = null;
    if (hasPending) {
      hasPending = false;
      controller.add(pending as T);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      source.listen(
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
    },
  );
  return controller.stream;
}

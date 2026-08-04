import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/features/preview/application/throttle_stream.dart';

/// [throttleStream] 节流语义测试(尾缘合并 + 取消/关闭清理)。
void main() {
  test('窗口内多发事件收敛为一次,取最新值(尾缘)', () {
    fakeAsync((async) {
      final source = StreamController<int>.broadcast();
      final collected = <int>[];
      final sub = throttleStream(
        source.stream,
        const Duration(milliseconds: 200),
      ).listen(collected.add);

      source.add(1);
      source.add(2);
      async.elapse(const Duration(milliseconds: 50));
      expect(collected, isEmpty);

      source.add(3);
      async.elapse(const Duration(milliseconds: 200));
      expect(collected, [3], reason: '50ms 内两次事件合并,尾缘发最新值');

      source.add(4);
      async.elapse(const Duration(milliseconds: 250));
      expect(collected, [3, 4]);

      sub.cancel();
      source.close();
    });
  });

  test('source 关闭时冲刷未发射的尾缘事件', () {
    fakeAsync((async) {
      final source = StreamController<int>.broadcast();
      final collected = <int>[];
      final sub = throttleStream(
        source.stream,
        const Duration(milliseconds: 200),
      ).listen(collected.add);

      source.add(1);
      source.add(2);
      source.close();
      async.flushMicrotasks();

      expect(collected, [2], reason: '关闭时立即冲刷最新值');
      sub.cancel();
    });
  });

  test('取消订阅后不再发射', () {
    fakeAsync((async) {
      final source = StreamController<int>.broadcast();
      final collected = <int>[];
      final sub = throttleStream(
        source.stream,
        const Duration(milliseconds: 200),
      ).listen(collected.add);

      source.add(1);
      sub.cancel();
      async.elapse(const Duration(milliseconds: 250));
      expect(collected, isEmpty);

      source.close();
    });
  });
}

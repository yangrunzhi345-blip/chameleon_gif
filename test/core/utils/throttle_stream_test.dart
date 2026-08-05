import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/utils/throttle_stream.dart';

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

  test('取消时释放源订阅(防常驻监听泄漏,P7)', () {
    fakeAsync((async) {
      var sourceOnCancel = 0;
      final source = StreamController<int>.broadcast(
        onCancel: () {
          sourceOnCancel++;
        },
      );
      final sub = throttleStream(
        source.stream,
        const Duration(milliseconds: 200),
      ).listen((_) {});

      source.add(1);
      expect(sourceOnCancel, 0, reason: '未取消前源监听存活');
      sub.cancel();
      expect(sourceOnCancel, 1, reason: '取消 throttle 订阅必须释放源监听');
      // 释放后源事件不再驱动定时器/发射
      source.add(2);
      async.elapse(const Duration(milliseconds: 250));
      expect(sourceOnCancel, 1);
      source.close();
    });
  });
}

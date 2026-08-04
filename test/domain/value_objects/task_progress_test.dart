import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/value_objects/task_progress.dart';

void main() {
  group('TaskProgress', () {
    test('构造默认值', () {
      const p = TaskProgress(taskId: 1);
      expect(p.taskId, 1);
      expect(p.percent, 0.0);
      expect(p.elapsed, Duration.zero);
      expect(p.remaining, isNull);
      expect(p.speedKbPerSec, 0);
    });

    test('现状锁定:percent 不钳制(钳制属 ProgressParser 职责,改动需走功能提交)', () {
      const over = TaskProgress(taskId: 1, percent: 1.5);
      const under = TaskProgress(taskId: 1, percent: -0.2);
      expect(over.percent, 1.5);
      expect(under.percent, -0.2);
    });

    test('序列化往返', () {
      const p = TaskProgress(
        taskId: 7,
        percent: 0.42,
        elapsed: Duration(seconds: 3),
        remaining: Duration(seconds: 5),
        speedKbPerSec: 128,
      );
      final decoded = TaskProgress.fromJson(p.toJson());
      expect(decoded, p);
    });

    test('序列化缺字段回默认', () {
      final decoded = TaskProgress.fromJson(const {'taskId': 2});
      expect(decoded.percent, 0.0);
      expect(decoded.elapsed, Duration.zero);
      expect(decoded.remaining, isNull);
      expect(decoded.speedKbPerSec, 0);
    });

    test('值相等性(freezed 值语义)', () {
      expect(
        const TaskProgress(taskId: 1, percent: 0.5),
        const TaskProgress(taskId: 1, percent: 0.5),
      );
      expect(
        const TaskProgress(taskId: 1, percent: 0.5),
        isNot(const TaskProgress(taskId: 1, percent: 0.6)),
      );
      expect(
        const TaskProgress(taskId: 1),
        isNot(const TaskProgress(taskId: 2)),
      );
    });
  });
}

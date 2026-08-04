import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';

void main() {
  group('TaskState', () {
    test('六态齐备且 index 序稳定(持久化契约,防 schema 漂移)', () {
      expect(TaskState.values, [
        TaskState.idle,
        TaskState.queued,
        TaskState.running,
        TaskState.completed,
        TaskState.failed,
        TaskState.cancelled,
      ]);
    });

    test('isFinal:completed/cancelled 为终态', () {
      expect(TaskState.completed.isFinal, isTrue);
      expect(TaskState.cancelled.isFinal, isTrue);
    });

    test('isFinal:failed 可重试故非终态,其余非终态', () {
      expect(TaskState.failed.isFinal, isFalse);
      expect(TaskState.idle.isFinal, isFalse);
      expect(TaskState.queued.isFinal, isFalse);
      expect(TaskState.running.isFinal, isFalse);
    });

    test('isPending:queued/running 为待恢复状态', () {
      expect(TaskState.queued.isPending, isTrue);
      expect(TaskState.running.isPending, isTrue);
    });

    test('isPending:其余非待恢复', () {
      expect(TaskState.idle.isPending, isFalse);
      expect(TaskState.completed.isPending, isFalse);
      expect(TaskState.failed.isPending, isFalse);
      expect(TaskState.cancelled.isPending, isFalse);
    });
  });
}

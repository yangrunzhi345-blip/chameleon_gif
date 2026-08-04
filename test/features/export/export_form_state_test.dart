import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/export/application/export_state.dart';

/// [ExportFormState] 表单字段与 copyWith 契约(P4-WP2)。
void main() {
  test('初始态:生命周期 idle + 内置默认表单值', () {
    const s = ExportFormState.idle();
    expect(s.lifecycle, ExportLifecycle.idle);
    expect(s.fps, 15.0);
    expect(s.width, 480);
    expect(s.loop, 0);
    expect(s.start, Duration.zero);
    expect(s.end, isNull);
    expect(s.outputDir, isNull);
    expect(s.locked, isFalse);
  });

  test('exporting 态 locked', () {
    const s = ExportFormState.exporting(1);
    expect(s.locked, isTrue);
  });

  test('copyWith 生命周期转换保留表单值', () {
    var s = const ExportFormState.idle().copyWith(fps: 24, width: 640);
    s = s.copyWith(lifecycle: ExportLifecycle.exporting, taskId: 3);
    expect(s.lifecycle, ExportLifecycle.exporting);
    expect(s.taskId, 3);
    expect(s.fps, 24, reason: '表单值不被生命周期转换重置');
    expect(s.width, 640);

    s = s.copyWith(lifecycle: ExportLifecycle.done, task: null, taskId: null);
    expect(s.fps, 24);
    expect(s.taskId, isNull, reason: 'copyWith 支持显式置 null');
  });

  test('copyWith 显式置 null(end/errorMessage/formError)', () {
    var s = const ExportFormState.idle().copyWith(
      end: const Duration(seconds: 5),
      formError: '时间格式非法',
      errorMessage: '失败',
    );
    s = s.copyWith(end: null, formError: null, errorMessage: null);
    expect(s.end, isNull);
    expect(s.formError, isNull);
    expect(s.errorMessage, isNull);
  });

  test('done 态构造与字段', () {
    final task = ExportTask(
      id: 1,
      videoPath: '/tmp/a.mp4',
      settings: const GifSetting(),
      state: TaskState.completed,
      createdAt: DateTime(2026, 1, 1),
    );
    final s = ExportFormState.done(task, 1234);
    expect(s.lifecycle, ExportLifecycle.done);
    expect(s.task, same(task));
    expect(s.outputSizeBytes, 1234);
  });
}

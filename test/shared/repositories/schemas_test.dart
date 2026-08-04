import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/export_history.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/shared/repositories/schemas/export_history_schema.dart';
import 'package:gif_forge/shared/repositories/schemas/export_task_schema.dart';

/// Isar 集合 fromEntity/toEntity 往返(docs/14 §14.2 模型序列化,P5 仓储前置)。
void main() {
  group('ExportTaskSchema 往返', () {
    final task = ExportTask(
      id: 7,
      videoPath: '/tmp/videos/demo.mp4',
      outputPath: '/tmp/gifforge_7/out.gif',
      settings: const GifSetting(fps: 24, width: 320, loop: 2),
      state: TaskState.completed,
      progress: 1.0,
      errorCode: null,
      errorDetail: null,
      retryCount: 1,
      createdAt: DateTime(2026, 8, 4, 10),
      startedAt: DateTime(2026, 8, 4, 10, 0, 1),
      finishedAt: DateTime(2026, 8, 4, 10, 0, 5),
    );

    test('全字段往返一致', () {
      final back = ExportTaskSchema.fromEntity(task).toEntity();
      expect(back.id, task.id);
      expect(back.videoPath, task.videoPath);
      expect(back.outputPath, task.outputPath);
      expect(back.settings, task.settings);
      expect(back.state, task.state);
      expect(back.progress, task.progress);
      expect(back.retryCount, task.retryCount);
      expect(back.createdAt, task.createdAt);
      expect(back.startedAt, task.startedAt);
      expect(back.finishedAt, task.finishedAt);
    });

    test('可空字段(失败任务)往返保持 null', () {
      final failed = ExportTask(
        id: 1,
        videoPath: '/tmp/a.mp4',
        settings: const GifSetting(),
        state: TaskState.failed,
        createdAt: DateTime(2026, 1, 1),
        errorCode: 'GIF_1_ENCODE',
        errorDetail: '转换失败',
      );
      final back = ExportTaskSchema.fromEntity(failed).toEntity();
      expect(back.outputPath, isNull);
      expect(back.startedAt, isNull);
      expect(back.finishedAt, isNull);
      expect(back.errorCode, 'GIF_1_ENCODE');
      expect(back.errorDetail, '转换失败');
    });
  });

  group('ExportHistorySchema 往返', () {
    test('全字段往返一致', () {
      final history = ExportHistory(
        id: 3,
        videoPath: '/tmp/videos/demo.mp4',
        outputPath: '/tmp/gifforge_3/out.gif',
        settings: const GifSetting(),
        durationMs: 1200,
        outputSizeBytes: 2048,
        createdAt: DateTime(2026, 8, 4, 11),
        sourceDurationMs: 10000,
        outputFrameCount: 150,
      );
      final back = ExportHistorySchema.fromEntity(history).toEntity();
      expect(back.id, history.id);
      expect(back.videoPath, history.videoPath);
      expect(back.outputPath, history.outputPath);
      expect(back.settings, history.settings);
      expect(back.durationMs, history.durationMs);
      expect(back.outputSizeBytes, history.outputSizeBytes);
      expect(back.createdAt, history.createdAt);
      expect(back.sourceDurationMs, history.sourceDurationMs);
      expect(back.outputFrameCount, history.outputFrameCount);
    });
  });
}

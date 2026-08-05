import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/export_history.dart';
import 'package:chameleon_gif/domain/entities/export_preset.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_history_schema.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_preset_schema.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_task_schema.dart';

/// Isar 集合 fromEntity/toEntity 往返(docs/14 §14.2 模型序列化,P5 仓储前置)。
void main() {
  group('ExportTaskSchema 迁移容错', () {
    test('galleryStatus 越界(Int64.min,迁移遗留)→ 回退 unsupported,整行可读', () {
      final schema = ExportTaskSchema.fromEntity(
        ExportTask(
          id: 1,
          videoPath: '/tmp/videos/demo.mp4',
          settings: const GifSetting(),
          state: TaskState.completed,
          createdAt: DateTime(2026, 8, 5),
        ),
      );
      // 模拟 isar_community 3.3.2 迁移 bug:新增非空 long 列旧行读到 Int64.min
      schema.galleryStatus = -9223372036854775808;

      final entity = schema.toEntity();
      expect(
        entity.galleryStatus,
        GallerySaveStatus.unsupported,
        reason: '越界索引回退桌面默认,不抛 RangeError 保住整行',
      );
      expect(entity.videoPath, '/tmp/videos/demo.mp4');
      expect(entity.state, TaskState.completed);
    });

    test('galleryStatus 正常索引不受影响', () {
      final schema = ExportTaskSchema.fromEntity(
        ExportTask(
          id: 1,
          videoPath: '/tmp/videos/demo.mp4',
          settings: const GifSetting(),
          state: TaskState.queued,
          createdAt: DateTime(2026, 8, 5),
          galleryStatus: GallerySaveStatus.saved,
          galleryPath: 'Pictures/GIFForge/demo.gif',
        ),
      );
      final entity = schema.toEntity();
      expect(entity.galleryStatus, GallerySaveStatus.saved);
      expect(entity.galleryPath, 'Pictures/GIFForge/demo.gif');
    });
  });

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

    group('ExportPresetSchema 往返', () {
      test('全字段往返一致', () {
        final preset = ExportPreset(
          id: 9,
          name: '默认 480p',
          settings: const GifSetting(fps: 24, width: 480, loop: 1),
          createdAt: DateTime(2026, 8, 4, 12),
        );
        final back = ExportPresetSchema.fromEntity(preset).toEntity();
        expect(back.id, preset.id);
        expect(back.name, preset.name);
        expect(back.settings, preset.settings);
        expect(back.createdAt, preset.createdAt);
      });
    });
  });
}

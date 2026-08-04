import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_history.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/shared/repositories/isar_history_repository.dart';
import 'package:gif_forge/shared/repositories/isar_task_repository.dart';
import 'package:gif_forge/shared/repositories/schemas/export_history_schema.dart';
import 'package:gif_forge/shared/repositories/schemas/export_task_schema.dart';
import 'package:isar_community/isar.dart';

import '../../fixtures/isar_test_helper.dart';

/// [IsarTaskRepository]/[IsarHistoryRepository] 测试(docs/14 §14.2 Isar 仓储)。
///
/// isar_community 无内存模式,用独立临时目录实例;tearDown 先 close 再删目录
/// (同名同 isolate 重复 open 抛 IsarError)。
void main() {
  setUpAll(initIsarNative);

  final logger = AppLogger();
  late Directory dir;
  late Isar isar;
  late IsarTaskRepository taskRepo;
  late IsarHistoryRepository historyRepo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gifforge_isar_');
    isar = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: dir.path);
    taskRepo = IsarTaskRepository(isar, logger: logger);
    historyRepo = IsarHistoryRepository(isar, logger: logger);
  });

  tearDown(() async {
    // 跨实例测试体内已 close,防二次 close 抛错
    if (isar.isOpen) {
      await isar.close();
    }
    await dir.delete(recursive: true);
  });

  ExportTask task(
    int id, {
    TaskState state = TaskState.queued,
    DateTime? createdAt,
  }) {
    return ExportTask(
      id: id,
      videoPath: '/tmp/videos/demo.mp4',
      settings: const GifSetting(fps: 24, width: 320, loop: 2),
      state: state,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );
  }

  ExportHistory history(int id, {DateTime? createdAt, GifSetting? settings}) {
    return ExportHistory(
      id: id,
      videoPath: '/tmp/videos/demo.mp4',
      outputPath: '/tmp/gifforge_1/out.gif',
      settings: settings ?? const GifSetting(fps: 24, width: 320),
      durationMs: 1200,
      outputSizeBytes: 2048,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      sourceDurationMs: 10000,
      outputFrameCount: 150,
    );
  }

  group('IsarTaskRepository', () {
    test('add 返回自增 id 且连续递增', () async {
      final id1 = await taskRepo.add(task(0));
      final id2 = await taskRepo.add(task(0));
      expect(id1, 1);
      expect(id2, 2);
    });

    test('update 后 byId 读回全部字段', () async {
      final id = await taskRepo.add(task(0));
      await taskRepo.update(
        task(id).copyWith(state: TaskState.running, progress: 0.5),
      );
      final back = await taskRepo.byId(id);
      expect(back!.state, TaskState.running);
      expect(back.progress, 0.5);
      expect(back.settings, const GifSetting(fps: 24, width: 320, loop: 2));
    });

    test('byId 不存在返回 null', () async {
      expect(await taskRepo.byId(99), isNull);
    });

    test(
      'pending 只含 queued+running(排除 idle/completed/failed/cancelled)',
      () async {
        final queued = await taskRepo.add(task(0, state: TaskState.queued));
        final running = await taskRepo.add(task(0, state: TaskState.running));
        await taskRepo.add(task(0, state: TaskState.idle));
        await taskRepo.add(task(0, state: TaskState.completed));
        await taskRepo.add(task(0, state: TaskState.failed));
        await taskRepo.add(task(0, state: TaskState.cancelled));

        final pending = await taskRepo.pending();
        expect(pending.map((t) => t.id).toSet(), {queued, running});
      },
    );

    test('all 按 id 升序', () async {
      await taskRepo.add(task(0));
      await taskRepo.add(task(0));
      final all = await taskRepo.all();
      expect(all.map((t) => t.id).toList(), [1, 2]);
    });

    test('delete 后 byId 为 null', () async {
      final id = await taskRepo.add(task(0));
      await taskRepo.delete(id);
      expect(await taskRepo.byId(id), isNull);
    });

    test('损坏 settingsJson 容错:byId 返回 null,其余行正常', () async {
      final good = await taskRepo.add(task(0));
      // 手工写入损坏行
      final broken = ExportTaskSchema.fromEntity(task(0));
      await isar.writeTxn(() => isar.exportTaskSchemas.put(broken));
      await isar.writeTxn(
        () => isar.exportTaskSchemas.put(
          ExportTaskSchema.fromEntity(task(0))..settingsJson = '{bad json',
        ),
      );

      expect(await taskRepo.byId(good), isNotNull);
      // 损坏行 id 未知,验证 all() 只含正常行
      final all = await taskRepo.all();
      expect(all, hasLength(1));
      expect(all.single.id, good);
    });
  });

  group('IsarHistoryRepository', () {
    test('add 自增 id;list 按 createdAt 倒序', () async {
      await historyRepo.add(history(0, createdAt: DateTime(2026, 1, 3)));
      await historyRepo.add(history(0, createdAt: DateTime(2026, 1, 1)));
      await historyRepo.add(history(0, createdAt: DateTime(2026, 1, 2)));

      final list = await historyRepo.list();
      expect(list.map((h) => h.createdAt.day).toList(), [3, 2, 1]);
    });

    test('byId 命中/未命中', () async {
      final id = await historyRepo.add(history(0));
      expect((await historyRepo.byId(id))!.outputSizeBytes, 2048);
      expect(await historyRepo.byId(99), isNull);
    });

    test('delete 移除;clear 清空', () async {
      final id1 = await historyRepo.add(history(0));
      await historyRepo.add(history(0));
      await historyRepo.delete(id1);
      expect(await historyRepo.list(), hasLength(1));

      await historyRepo.clear();
      expect(await historyRepo.list(), isEmpty);
    });

    test('损坏 settingsJson 容错:list 跳过损坏行', () async {
      await historyRepo.add(history(0));
      await isar.writeTxn(
        () => isar.exportHistorySchemas.put(
          ExportHistorySchema.fromEntity(history(0))
            ..settingsJson = '{bad json',
        ),
      );

      final list = await historyRepo.list();
      expect(list, hasLength(1), reason: '损坏行跳过,正常行保留');
    });
  });

  test('跨实例落盘:close 后重开同目录数据仍在', () async {
    final id = await historyRepo.add(history(0));
    await isar.close();

    final reopened = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: dir.path);
    addTearDown(() => reopened.close());
    final repo = IsarHistoryRepository(reopened, logger: logger);
    expect((await repo.byId(id))!.outputPath, '/tmp/gifforge_1/out.gif');
  });
}

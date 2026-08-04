import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/isar_history_repository.dart';
import 'package:gif_forge/shared/repositories/isar_task_repository.dart';
import 'package:gif_forge/shared/repositories/schemas/export_history_schema.dart';
import 'package:gif_forge/shared/repositories/schemas/export_task_schema.dart';
import 'package:isar_community/isar.dart';

import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/isar_test_helper.dart';

/// P6-WP3 崩溃恢复集成测试(阶段门"kill 进程重启队列恢复"的自动化等价物)。
///
/// Isar 实例 A 直写崩溃残局(2 running + 1 queued)→ close(模拟进程死亡)
/// → 同目录重开实例 B + 新 TaskManager → start() → 全部重置 queued 重排,
/// 双槽同时执行 → 完成且历史 3 条。
void main() {
  final logger = AppLogger();
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  late Directory dir;
  late Isar isarA;
  late IsarTaskRepository taskRepoA;

  setUpAll(initIsarNative);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gifforge_crash_');
    isarA = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: dir.path);
    taskRepoA = IsarTaskRepository(isarA, logger: logger);
  });

  tearDown(() async {
    if (isarA.isOpen) await isarA.close();
    await dir.delete(recursive: true);
  });

  Future<int> seedTask(TaskState state) {
    return taskRepoA.add(
      ExportTask(
        id: 0,
        videoPath: video.path,
        settings: const GifSetting(),
        state: state,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  test('崩溃残局(2 running + 1 queued)→ 重启恢复重排执行,历史 3 条', () async {
    final r1 = await seedTask(TaskState.running);
    final r2 = await seedTask(TaskState.running);
    final q3 = await seedTask(TaskState.queued);

    // 模拟进程死亡:关闭实例
    await isarA.close();

    // 重启:同目录重开 + 新仓储 + 新 TaskManager(占双槽阻塞)
    final isarB = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: dir.path);
    addTearDown(() => isarB.close());
    final taskRepoB = IsarTaskRepository(isarB, logger: logger);
    final historyRepoB = IsarHistoryRepository(isarB, logger: logger);
    final service = FakeFfmpegService(blockNthConvert: [1, 2]);
    final manager = TaskManager(
      taskRepository: taskRepoB,
      historyRepository: historyRepoB,
      ffmpegService: service,
      platformAdapter: _TestAdapter(dir.path),
      logger: logger,
      retryDelay: (_) async {},
    );

    // 恢复扫描:全部重置 queued 重排,双槽同时执行(阻塞稳定)
    await manager.start();
    for (var i = 0; i < 100; i++) {
      if (service.convertCalls.length >= 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(service.convertCalls.toSet(), {
      r1,
      r2,
    }, reason: '恢复后前 2 个任务同时 running');
    final t3 = await taskRepoB.byId(q3);
    expect(t3!.state, TaskState.queued, reason: '第 3 个排队');

    // 放行 → 全部完成
    service.unblockAll();
    for (final id in [r1, r2, q3]) {
      for (var i = 0; i < 100; i++) {
        final t = await taskRepoB.byId(id);
        if (t?.state == TaskState.completed) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect((await taskRepoB.byId(id))!.state, TaskState.completed);
    }
    expect(await historyRepoB.list(), hasLength(3), reason: '历史 3 条');
  });

  test('恢复重置:running 任务带错误残留 → queued 且 errorCode/errorDetail 清零', () async {
    final crashedId = await taskRepoA.add(
      ExportTask(
        id: 0,
        videoPath: video.path,
        settings: const GifSetting(),
        state: TaskState.running,
        errorCode: 'GIF_1_ENCODE',
        errorDetail: '陈旧错误文案',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await isarA.close();

    final isarB = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: dir.path);
    addTearDown(() => isarB.close());
    final taskRepoB = IsarTaskRepository(isarB, logger: logger);
    final manager = TaskManager(
      taskRepository: taskRepoB,
      historyRepository: IsarHistoryRepository(isarB, logger: logger),
      ffmpegService: FakeFfmpegService(),
      platformAdapter: _TestAdapter(dir.path),
      logger: logger,
      retryDelay: (_) async {},
    );

    await manager.start();

    final restored = await taskRepoB.byId(crashedId);
    expect(restored!.state, TaskState.queued, reason: 'running 重置 queued');
    expect(restored.errorCode, isNull, reason: '错误码清零,不阻碍重排');
    expect(restored.errorDetail, isNull, reason: '错误文案一并清理');
    // 恢复任务正常执行完成
    for (var i = 0; i < 100; i++) {
      final t = await taskRepoB.byId(crashedId);
      if (t?.state == TaskState.completed) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect((await taskRepoB.byId(crashedId))!.state, TaskState.completed);
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

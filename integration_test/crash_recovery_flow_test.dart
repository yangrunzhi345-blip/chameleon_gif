import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/platform/process_engine.dart';
import 'package:chameleon_gif/shared/repositories/isar_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/isar_task_repository.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_history_schema.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_task_schema.dart';
import 'package:isar_community/isar.dart';

import '../test/fixtures/isar_test_helper.dart';

/// P8 崩溃恢复全链路(无头 + **真实 ffmpeg**,需桌面环境 + 系统 ffmpeg):
///   flutter test -d linux integration_test/crash_recovery_flow_test.dart
///
/// Isar 实例 A 直写崩溃残局(1 running + 1 queued,真实夹具视频)→ close
/// (模拟进程死亡)→ 同目录重开实例 B + 新 TaskManager(真实 ProcessEngine)
/// → start() 恢复重排 → 真实转码 2 段 → completed 且历史 2 条。
///
/// 相比 task_queue_crash_recovery_test(单测,fake 服务):本文件验证
/// "kill 重启"链路端到端落盘(真实 Isar + 真实 ffmpeg 二进制)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final logger = AppLogger();
  const clipA = 'test/fixtures/videos/clip_a.mp4';
  const clipB = 'test/fixtures/videos/clip_b.mp4';

  late Directory tempRoot;
  late Isar isarA;
  late IsarTaskRepository taskRepoA;

  setUpAll(initIsarNative);

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('gifforge_recover_');
    isarA = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: tempRoot.path);
    taskRepoA = IsarTaskRepository(isarA, logger: logger);
  });

  tearDown(() async {
    if (isarA.isOpen) {
      await isarA.close();
    }
    await tempRoot.delete(recursive: true);
  });

  test('崩溃残局(1 running + 1 queued)→ 重启恢复真实转码,历史 2 条', () async {
    // 崩溃前:1 个 running + 1 个 queued(真实夹具视频)
    final runningId = await taskRepoA.add(
      ExportTask(
        id: 0,
        videoPath: '${Directory.current.path}/$clipA',
        settings: const GifSetting(),
        state: TaskState.running,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final queuedId = await taskRepoA.add(
      ExportTask(
        id: 0,
        videoPath: '${Directory.current.path}/$clipB',
        settings: const GifSetting(),
        state: TaskState.queued,
        createdAt: DateTime(2026, 1, 2),
      ),
    );

    // 模拟进程死亡:关闭实例
    await isarA.close();

    // 重启:同目录重开 + 真实引擎
    final isarB = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: tempRoot.path);
    addTearDown(() => isarB.close());
    final taskRepoB = IsarTaskRepository(isarB, logger: logger);
    final manager = TaskManager(
      taskRepository: taskRepoB,
      historyRepository: IsarHistoryRepository(isarB, logger: logger),
      ffmpegService: FfmpegServiceEngine(
        engine: const ProcessEngine(),
        logger: logger,
      ),
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: logger,
    );

    // 恢复扫描:重置 queued 重排,真实转码直至完成
    await manager.start();
    for (final id in [runningId, queuedId]) {
      for (var i = 0; i < 600; i++) {
        final t = await taskRepoB.byId(id);
        if (t?.state == TaskState.completed) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        (await taskRepoB.byId(id))!.state,
        TaskState.completed,
        reason: '恢复任务真实转码完成: task#$id',
      );
    }

    // 产物可解码 + 历史入库
    final history = await IsarHistoryRepository(isarB, logger: logger).list();
    expect(history, hasLength(2), reason: '历史 2 条');
    for (final h in history) {
      final bytes = await File(h.outputPath).readAsBytes();
      expect(String.fromCharCodes(bytes.take(4)), 'GIF8');
    }
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

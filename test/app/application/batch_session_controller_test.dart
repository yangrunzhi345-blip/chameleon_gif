import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/batch_session_controller.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_ffmpeg_service.dart';

/// 批量会话状态机测试:derive 纯函数全分支 + 控制器行为(重试/decline/clear)。
void main() {
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  ExportTask task(
    int id,
    TaskState state, {
    String? outputPath,
    String? errorDetail,
  }) => ExportTask(
    id: id,
    videoPath: '/tmp/videos/v$id.mp4',
    settings: const GifSetting(),
    state: state,
    createdAt: DateTime(2026, 1, 1),
    outputPath: outputPath,
    errorDetail: errorDetail,
  );

  group('derive 纯函数', () {
    test('空 taskIds → none', () {
      final s = derive(taskIds: const [], tasks: [], declined: false);
      expect(s.phase, BatchSessionPhase.none);
      expect(s.failedItems, isEmpty);
    });

    test('全 completed → finished,stats 3/0/0,gifPaths 过滤 outputPath 空', () {
      final s = derive(
        taskIds: const [1, 2, 3],
        tasks: [
          task(1, TaskState.completed, outputPath: '/tmp/a.gif'),
          task(2, TaskState.completed),
          task(3, TaskState.completed, outputPath: '/tmp/c.gif'),
        ],
        declined: false,
      );
      expect(s.phase, BatchSessionPhase.finished);
      expect(s.stats.completed, 3);
      expect(s.stats.failed, 0);
      expect(s.stats.cancelled, 0);
      expect(s.stats.completedGifPaths, ['/tmp/a.gif', '/tmp/c.gif']);
      expect(s.failedItems, isEmpty);
    });

    test('含 failed → askRetry,failedItems 按入队顺序含 errorDetail', () {
      final s = derive(
        taskIds: const [1, 2, 3],
        tasks: [
          task(1, TaskState.completed, outputPath: '/tmp/a.gif'),
          task(2, TaskState.failed, errorDetail: '编码失败'),
          task(3, TaskState.failed),
        ],
        declined: false,
      );
      expect(s.phase, BatchSessionPhase.askRetry);
      expect(s.failedItems, hasLength(2));
      expect(s.failedItems.first.path, '/tmp/videos/v2.mp4');
      expect(s.failedItems.first.errorDetail, '编码失败');
      expect(s.stats.completed, 1);
      expect(s.stats.failed, 2);
    });

    test('含 cancelled → finished(不询问),cancelled 仅入统计', () {
      final s = derive(
        taskIds: const [1, 2],
        tasks: [
          task(1, TaskState.completed, outputPath: '/tmp/a.gif'),
          task(2, TaskState.cancelled),
        ],
        declined: false,
      );
      expect(s.phase, BatchSessionPhase.finished);
      expect(s.stats.cancelled, 1);
      expect(s.failedItems, isEmpty);
    });

    test('failed + declined=true → 跳过询问直接 finished,failed 入统计', () {
      final s = derive(
        taskIds: const [1, 2],
        tasks: [task(1, TaskState.failed), task(2, TaskState.cancelled)],
        declined: true,
      );
      expect(s.phase, BatchSessionPhase.finished);
      expect(s.stats.failed, 1);
      expect(s.stats.cancelled, 1);
    });

    test('存在 queued/running → running(未落定不弹)', () {
      final q = derive(
        taskIds: const [1, 2],
        tasks: [task(1, TaskState.completed), task(2, TaskState.queued)],
        declined: false,
      );
      expect(q.phase, BatchSessionPhase.running);
      final r = derive(
        taskIds: const [1, 2],
        tasks: [task(1, TaskState.completed), task(2, TaskState.running)],
        declined: false,
      );
      expect(r.phase, BatchSessionPhase.running);
    });

    test('混合 failed+cancelled → askRetry 且 failedItems 只含 failed', () {
      final s = derive(
        taskIds: const [1, 2],
        tasks: [task(1, TaskState.failed), task(2, TaskState.cancelled)],
        declined: false,
      );
      expect(s.phase, BatchSessionPhase.askRetry);
      expect(s.failedItems, hasLength(1));
    });
  });

  group('BatchSessionController(容器)', () {
    late ProviderContainer container;
    late InMemoryTaskRepository repo;
    late FakeFfmpegService service;
    late Directory tempRoot;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = InMemoryTaskRepository();
      tempRoot = await Directory.systemTemp.createTemp('gifforge_batch_ses_');
    });

    tearDown(() {
      container.dispose();
      tempRoot.deleteSync(recursive: true);
    });

    void buildContainer(FakeFfmpegService svc) {
      service = svc;
      container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appLoggerProvider.overrideWithValue(AppLogger()),
          platformAdapterProvider.overrideWithValue(
            _TestAdapter(tempRoot.path),
          ),
          taskRepositoryProvider.overrideWithValue(repo),
          historyRepositoryProvider.overrideWithValue(
            InMemoryHistoryRepository(),
          ),
          ffmpegServiceProvider.overrideWithValue(service),
          taskManagerProvider.overrideWith(
            (ref) => TaskManager(
              taskRepository: ref.read(taskRepositoryProvider),
              historyRepository: ref.read(historyRepositoryProvider),
              ffmpegService: service,
              platformAdapter: _TestAdapter(tempRoot.path),
              logger: AppLogger(),
              retryDelay: (_) async {},
              concurrency: 1, // 单槽:convert 调用序号与 taskId 顺序稳定
            ),
          ),
        ],
      )..listen(taskQueueControllerProvider, (_, _) {});
    }

    BatchSessionState state() => container.read(batchSessionProvider);

    TaskQueueController queueCtl() =>
        container.read(taskQueueControllerProvider.notifier);

    BatchSessionController sessionCtl() =>
        container.read(batchSessionProvider.notifier);

    /// 宿主视角派生:会话声明 + 队列快照 → phase/统计。
    BatchSessionSnapshot snapshot() => derive(
      taskIds: state().taskIds,
      tasks: container.read(taskQueueControllerProvider).tasks,
      declined: state().declined,
    );

    Future<BatchSessionSnapshot> waitPhase(BatchSessionPhase phase) async {
      for (var i = 0; i < 200; i++) {
        final s = snapshot();
        if (s.phase == phase) return s;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('等待阶段 $phase 超时,当前 ${snapshot().phase}');
    }

    test('begin → retryFailed 仅重试失败项,重试成功后 finished', () async {
      // 第 1 次 convert 失败(SourceBroken 不可重试,直接落 failed),其余成功
      buildContainer(
        FakeFfmpegService(
          errorQueue: [
            const SourceBrokenException(errorCode: 'GIF_SRC_BROKEN'),
          ],
        ),
      );
      final id1 = await queueCtl().submit(const GifSetting(), video);
      final id2 = await queueCtl().submit(const GifSetting(), video);
      sessionCtl().begin([id1, id2]);

      // 落定:task1 失败、task2 成功 → askRetry
      final s1 = await waitPhase(BatchSessionPhase.askRetry);
      expect(s1.stats.completed, 1);
      expect(s1.stats.failed, 1);
      expect(s1.failedItems.single.path, video.path);

      await sessionCtl().retryFailed();

      // 重试成功后再次落定 → finished(全部成功);仅失败项重试:
      // task2 已成功不再执行,convert 调用共 3 次
      final s2 = await waitPhase(BatchSessionPhase.finished);
      expect(s2.stats.completed, 2);
      expect(s2.stats.failed, 0);
      expect(service.convertCalls, hasLength(3));
    });

    test('重试循环:service 恒失败 → 再落定仍 askRetry;decline 后 finished', () async {
      buildContainer(
        FakeFfmpegService(
          error: const SourceBrokenException(errorCode: 'GIF_SRC_BROKEN'),
        ),
      );
      final id = await queueCtl().submit(const GifSetting(), video);
      sessionCtl().begin([id]);
      await waitPhase(BatchSessionPhase.askRetry);

      // 重试 → 回 running → 再失败 → 仍 askRetry(循环判定)
      await sessionCtl().retryFailed();
      await waitPhase(BatchSessionPhase.askRetry);
      expect(service.convertCalls, hasLength(2), reason: '重试后重新执行');

      // 点"否" → 跳过询问 → finished
      sessionCtl().decline();
      final s = await waitPhase(BatchSessionPhase.finished);
      expect(s.stats.failed, 1);

      // 清理 → none(防重复弹窗)
      sessionCtl().clear();
      expect(snapshot().phase, BatchSessionPhase.none);
      expect(state().taskIds, isEmpty);
    });

    test('begin 替换旧会话(边界:不清除旧批次)', () async {
      buildContainer(
        FakeFfmpegService(
          error: const SourceBrokenException(errorCode: 'GIF_SRC_BROKEN'),
        ),
      );
      final id1 = await queueCtl().submit(const GifSetting(), video);
      final id2 = await queueCtl().submit(const GifSetting(), video);
      sessionCtl().begin([id1]);
      sessionCtl().begin([id2]);
      expect(state().taskIds, [id2]);
    });
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

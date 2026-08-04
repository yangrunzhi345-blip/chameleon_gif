import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/encode_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_progress.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/in_memory_history_repository.dart';
import 'package:gif_forge/shared/repositories/in_memory_task_repository.dart';

/// [TaskManager] 状态机测试(docs/14 §14.2/§14.8,覆盖率目标 task_queue ≥80%)。
void main() {
  final logger = AppLogger();
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mov,mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  late InMemoryTaskRepository repo;
  late InMemoryHistoryRepository historyRepo;
  late FakeFfmpegService service;
  late Directory tempRoot;
  late TaskManager manager;

  TaskManager build({Object? serviceError, bool cancelOnRun = false}) {
    service = FakeFfmpegService(error: serviceError, cancelOnRun: cancelOnRun);
    return TaskManager(
      taskRepository: repo,
      historyRepository: historyRepo,
      ffmpegService: service,
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: logger,
      retryDelay: (_) async {}, // 测试立即重试
    );
  }

  setUp(() async {
    repo = InMemoryTaskRepository();
    historyRepo = InMemoryHistoryRepository();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_tq_');
    manager = build();
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Future<ExportTask> waitForState(int id, TaskState state) async {
    for (var i = 0; i < 100; i++) {
      final t = await repo.byId(id);
      if (t?.state == state) return t!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待状态超时: id=$id state=$state');
  }

  test('submit:queued → running → completed(输出路径 + 历史快照入库)', () async {
    final id = await manager.submit(const GifSetting(), video);

    final task = await waitForState(id, TaskState.completed);
    expect(task.outputPath, endsWith('/gifforge_$id/out.gif'));
    expect(service.convertCalls, [id]);
    expect(task.settings.end, video.duration, reason: 'end 缺省装配源时长');

    final histories = await historyRepo.list();
    expect(histories, hasLength(1));
    final h = histories.single;
    expect(h.videoPath, video.path);
    expect(h.outputSizeBytes, 123);
    expect(h.durationMs, 1000);
    expect(h.sourceDurationMs, 10000);
    expect(h.outputFrameCount, 150); // 15fps × 10s
  });

  test('FIFO 单槽:第二个任务排队,第一个完成后才执行', () async {
    // 用阻塞服务占住槽位,确定检查时刻 id2 必在排队
    final slow = FakeFfmpegService(blockFirstConvert: true);
    final m = TaskManager(
      taskRepository: repo,
      historyRepository: historyRepo,
      ffmpegService: slow,
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: logger,
      retryDelay: (_) async {},
    );
    final id1 = await m.submit(const GifSetting(), video);
    await waitForState(id1, TaskState.running);
    final id2 = await m.submit(const GifSetting(), video);

    final t2 = await repo.byId(id2);
    expect(t2!.state, TaskState.queued);
    expect(slow.convertCalls, [id1], reason: '槽位被第一个任务占用');

    slow.unblock();
    await waitForState(id1, TaskState.completed);
    await waitForState(id2, TaskState.completed);
    expect(slow.convertCalls, [id1, id2], reason: '严格 FIFO 执行顺序');
  });

  test('进度流:onProgress 回调 → task.progress 更新', () async {
    final progresses = <TaskProgress>[];
    final sub = manager.progressStream.listen(progresses.add);
    final id = await manager.submit(const GifSetting(), video);
    await waitForState(id, TaskState.completed);

    expect(progresses, isNotEmpty);
    expect(progresses.last.taskId, id);
    expect(progresses.last.percent, 0.5);
    final task = await repo.byId(id);
    expect(task!.progress, 0.5);
    await sub.cancel();
  });

  group('cancel', () {
    test('queued 任务取消 → 直接 cancelled', () async {
      // 用慢任务占住槽位,让第二个任务保持 queued
      final slow = FakeFfmpegService(blockFirstConvert: true);
      service = slow;
      final blocked = TaskManager(
        taskRepository: repo,
        historyRepository: historyRepo,
        ffmpegService: slow,
        platformAdapter: _TestAdapter(tempRoot.path),
        logger: logger,
        retryDelay: (_) async {},
      );
      final id1 = await blocked.submit(const GifSetting(), video);
      await waitForState(id1, TaskState.running);
      final id2 = await blocked.submit(const GifSetting(), video);

      await blocked.cancel(id2);

      final t2 = await repo.byId(id2);
      expect(t2!.state, TaskState.cancelled);
      slow.unblock();
      await waitForState(id1, TaskState.completed);
    });

    test('running 任务取消 → token 标记 + 转换侧 cancelled 收尾', () async {
      final blocked = FakeFfmpegService(blockFirstConvert: true);
      final m = TaskManager(
        taskRepository: repo,
        historyRepository: historyRepo,
        ffmpegService: blocked,
        platformAdapter: _TestAdapter(tempRoot.path),
        logger: logger,
        retryDelay: (_) async {},
      );
      final id = await m.submit(const GifSetting(), video);
      await waitForState(id, TaskState.running);

      await m.cancel(id);

      expect(blocked.lastCancelToken?.isCancelled, isTrue);
      blocked.unblock();
      await waitForState(id, TaskState.cancelled);
    });

    test('终态任务重复取消无副作用', () async {
      final id = await manager.submit(const GifSetting(), video);
      await waitForState(id, TaskState.completed);

      await manager.cancel(id); // 不应抛、不改状态
      final task = await repo.byId(id);
      expect(task!.state, TaskState.completed);
    });
  });

  group('retry', () {
    test('EncodeException 可重试:重入队 + retryCount 递增,成功收尾', () async {
      final flaky = FakeFfmpegService(
        errorQueue: [const EncodeException(errorCode: 'GIF_1_ENCODE')],
      );
      final m = TaskManager(
        taskRepository: repo,
        historyRepository: historyRepo,
        ffmpegService: flaky,
        platformAdapter: _TestAdapter(tempRoot.path),
        logger: logger,
        retryDelay: (_) async {},
      );
      final id = await m.submit(const GifSetting(), video);

      final task = await waitForState(id, TaskState.completed);
      expect(task.retryCount, 1);
      expect(flaky.convertCalls, [id, id], reason: '失败后重试执行');
      // B1 回归:重试路径 _videos 已消费,兜底 video 宽度须取设置宽度,
      // 保证 scale 滤镜不因兜底缺失而输出原始分辨率
      expect(flaky.receivedVideos.last.width, 480);
    });

    test('重试超 2 次 → 终态 failed', () async {
      final failing = FakeFfmpegService(
        error: const EncodeException(errorCode: 'GIF_1_ENCODE'),
      );
      final m = TaskManager(
        taskRepository: repo,
        historyRepository: historyRepo,
        ffmpegService: failing,
        platformAdapter: _TestAdapter(tempRoot.path),
        logger: logger,
        retryDelay: (_) async {},
      );
      final id = await m.submit(const GifSetting(), video);

      final task = await waitForState(id, TaskState.failed);
      expect(task.retryCount, 2);
      expect(task.errorCode, 'GIF_1_ENCODE');
      expect(failing.convertCalls, hasLength(3), reason: '1 次 + 2 次重试');
    });

    test('SourceBroken/Palette 不可重试 → 直接终态 failed', () async {
      final broken = FakeFfmpegService(
        error: const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN'),
      );
      final m = TaskManager(
        taskRepository: repo,
        historyRepository: historyRepo,
        ffmpegService: broken,
        platformAdapter: _TestAdapter(tempRoot.path),
        logger: logger,
        retryDelay: (_) async {},
      );
      final id = await m.submit(const GifSetting(), video);

      final task = await waitForState(id, TaskState.failed);
      expect(task.retryCount, 0);
      expect(broken.convertCalls, hasLength(1));
      expect(task.errorDetail, isNotEmpty);
    });
  });

  test('恢复:预种子 queued+running → start() 全部重置 queued 重排队', () async {
    // 模拟崩溃会话:2 queued + 1 running 残留在仓储
    repo = InMemoryTaskRepository(
      seed: [
        ExportTask(
          id: 1,
          videoPath: video.path,
          settings: const GifSetting(),
          state: TaskState.queued,
          createdAt: DateTime(2026, 1, 1),
        ),
        ExportTask(
          id: 2,
          videoPath: video.path,
          settings: const GifSetting(),
          state: TaskState.running,
          createdAt: DateTime(2026, 1, 1),
        ),
        ExportTask(
          id: 3,
          videoPath: video.path,
          settings: const GifSetting(),
          state: TaskState.completed,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    final m = build();

    await m.start();

    final t1 = await repo.byId(1);
    final t2 = await repo.byId(2);
    final t3 = await repo.byId(3);
    expect(t1!.state, TaskState.queued);
    expect(t2!.state, TaskState.queued, reason: 'running 重置 queued');
    expect(t3!.state, TaskState.completed, reason: '终态不动');
    // 依次执行完毕
    await waitForState(1, TaskState.completed);
    await waitForState(2, TaskState.completed);
  });

  test('taskEvents:每个状态转移发事件,完成事件含输出路径', () async {
    final events = <ExportTask>[];
    final sub = manager.taskEvents.listen(events.add);
    final id = await manager.submit(const GifSetting(), video);
    await waitForState(id, TaskState.completed);
    await Future<void>.delayed(Duration.zero);

    final states = events.map((e) => e.state).toList();
    expect(states, contains(TaskState.queued));
    expect(states, contains(TaskState.running));
    expect(states, contains(TaskState.completed));
    final done = events.lastWhere((e) => e.state == TaskState.completed);
    expect(done.outputPath, isNotNull);
    await sub.cancel();
  });
}

class FakeFfmpegService implements FFmpegService {
  FakeFfmpegService({
    this.error,
    List<Object> errorQueue = const [],
    this.cancelOnRun = false,
    this.blockFirstConvert = false,
  }) : _errorQueue = List.of(errorQueue);

  final Object? error;
  final List<Object> _errorQueue;
  final bool cancelOnRun;
  final bool blockFirstConvert;

  final convertCalls = <int>[];
  final receivedVideos = <VideoInfo>[];
  CancelToken? lastCancelToken;
  Completer<void>? _blocker;

  /// 解除阻塞(blockFirstConvert 场景,模拟转换完成)。
  void unblock() => _blocker?.complete();

  @override
  Future<ConvertResult> convert({
    required GifSetting setting,
    required VideoInfo video,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    convertCalls.add(taskId);
    receivedVideos.add(video);
    lastCancelToken = cancelToken;
    if (cancelOnRun) cancelToken?.cancel();
    if (blockFirstConvert && convertCalls.length == 1) {
      _blocker = Completer<void>();
      await _blocker!.future;
      if (cancelToken?.isCancelled ?? false) {
        return ConvertResult(
          exitCode: -1,
          elapsed: Duration.zero,
          cancelled: true,
        );
      }
    }
    onProgress?.call(
      TaskProgress(
        taskId: taskId,
        percent: 0.5,
        elapsed: const Duration(seconds: 1),
      ),
    );
    if (_errorQueue.isNotEmpty) {
      final e = _errorQueue.removeAt(0);
      throw e;
    }
    if (error != null) throw error!;
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

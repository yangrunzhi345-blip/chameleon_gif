import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_state.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_ffmpeg_service.dart';

/// [TaskQueueController] 双槽状态测试(P6-WP2)。
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

  late ProviderContainer container;
  late InMemoryTaskRepository repo;
  late FakeFfmpegService service;
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = InMemoryTaskRepository();
    service = FakeFfmpegService(blockNthConvert: [1, 2]);
    tempRoot = await Directory.systemTemp.createTemp('gifforge_tqc_');
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
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
          ),
        ),
      ],
    )..listen(taskQueueControllerProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    tempRoot.deleteSync(recursive: true);
  });

  TaskQueueController ctl() =>
      container.read(taskQueueControllerProvider.notifier);

  Future<TaskQueueState> waitState(bool Function(TaskQueueState) cond) async {
    for (var i = 0; i < 200; i++) {
      final s = container.read(taskQueueControllerProvider);
      if (cond(s)) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待状态条件超时');
  }

  test('submit 3 任务 → running 收集 2 个,active = 首个', () async {
    await ctl().submit(const GifSetting(), video);
    await ctl().submit(const GifSetting(), video);
    await ctl().submit(const GifSetting(), video);

    final state = await waitState((s) => s.running.length == 2);
    expect(state.running, hasLength(2));
    expect(state.active, same(state.running.first));
    expect(state.tasks, hasLength(3));
    expect(state.tasks.last.state, TaskState.queued);
  });

  test('cancelAll 转发 → 全部取消', () async {
    await ctl().submit(const GifSetting(), video);
    await ctl().submit(const GifSetting(), video);
    await waitState((s) => s.running.length == 2);
    await ctl().submit(const GifSetting(), video);

    service.unblockAll();
    await ctl().cancelAll();

    final state = await waitState(
      (s) => s.tasks.isNotEmpty && s.tasks.every((t) => t.state.isFinal),
    );
    // 全部落终态(不挂起);排队任务必须 cancelled,running 任务在
    // 取消-完成竞态下 completed 亦可接受
    expect(state.tasks.every((t) => t.state.isFinal), isTrue);
    expect(state.tasks.last.state, TaskState.cancelled, reason: '排队任务直接取消');
  });

  test('seed 仓储(running+queued)→ build 自动恢复重排', () async {
    // 独立容器:seed 后触发 build 恢复
    repo = InMemoryTaskRepository(
      seed: [
        ExportTask(
          id: 1,
          videoPath: video.path,
          settings: const GifSetting(),
          state: TaskState.running,
          createdAt: DateTime(2026, 1, 1),
        ),
        ExportTask(
          id: 2,
          videoPath: video.path,
          settings: const GifSetting(),
          state: TaskState.queued,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    container.dispose();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = FakeFfmpegService(blockNthConvert: [1, 2]);
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(repo),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(svc),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: svc,
            platformAdapter: _TestAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    )..listen(taskQueueControllerProvider, (_, _) {});

    // build 触发 start() 恢复 → 双槽同时执行(阻塞稳定 running 2)
    final state = await waitState((s) => s.running.length == 2);
    expect(state.running, hasLength(2), reason: '恢复后 2 个任务同时 running');
    svc.unblockAll(); // 放行恢复的转换
    final done = await waitState(
      (s) => s.tasks.isNotEmpty && s.tasks.every((t) => t.state.isFinal),
    );
    expect(done.tasks.every((t) => t.state == TaskState.completed), isTrue);
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

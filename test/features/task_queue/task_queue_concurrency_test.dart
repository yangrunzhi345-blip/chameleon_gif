import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/encode_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/in_memory_history_repository.dart';
import 'package:gif_forge/shared/repositories/in_memory_task_repository.dart';

import '../../fixtures/fake_ffmpeg_service.dart';

/// P6-WP2 双槽并发调度测试。
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

  late InMemoryTaskRepository repo;
  late InMemoryHistoryRepository historyRepo;
  late FakeFfmpegService service;
  late Directory tempRoot;

  setUp(() async {
    repo = InMemoryTaskRepository();
    historyRepo = InMemoryHistoryRepository();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_cc_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  TaskManager build({
    int concurrency = 2,
    FakeFfmpegService? fake,
    List<int> blockNth = const [],
    Object? error,
  }) {
    service =
        fake ?? FakeFfmpegService(blockNthConvert: blockNth, error: error);
    return TaskManager(
      taskRepository: repo,
      historyRepository: historyRepo,
      ffmpegService: service,
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: logger,
      retryDelay: (_) async {},
      concurrency: concurrency,
    );
  }

  Future<ExportTask> waitForState(int id, TaskState state) async {
    for (var i = 0; i < 200; i++) {
      final t = await repo.byId(id);
      if (t?.state == state) return t!;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待状态超时: id=$id state=$state');
  }

  Future<void> waitForCount(int n) async {
    for (var i = 0; i < 200; i++) {
      if (service.convertCalls.length >= n) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待转换调用超时: 期望 $n 实际 ${service.convertCalls.length}');
  }

  test('双槽基本:3 任务 → 前 2 同时 running,第 3 排队', () async {
    final m = build(blockNth: [1, 2]); // 占满双槽
    final id1 = await m.submit(const GifSetting(), video);
    final id2 = await m.submit(const GifSetting(), video);
    final id3 = await m.submit(const GifSetting(), video);
    await waitForCount(2);

    expect(service.convertCalls.toSet(), {id1, id2});
    final t3 = await repo.byId(id3);
    expect(t3!.state, TaskState.queued, reason: '双槽占满,第 3 个排队');

    service.unblockAll();
    await waitForState(id3, TaskState.completed);
    expect(service.convertCalls.toSet(), {id1, id2, id3});
  });

  test('单槽兼容:concurrency=1 → 旧 FIFO 语义', () async {
    final m = build(concurrency: 1, blockNth: [1]);
    final id1 = await m.submit(const GifSetting(), video);
    final id2 = await m.submit(const GifSetting(), video);
    await waitForCount(1);

    final t2 = await repo.byId(id2);
    expect(t2!.state, TaskState.queued, reason: '单槽下第 2 个排队');
    expect(service.convertCalls, [id1]);

    service.unblockAll();
    await waitForState(id2, TaskState.completed);
    expect(service.convertCalls, [id1, id2], reason: '严格 FIFO');
  });

  test('失败隔离:不可重试失败不阻塞队列,全部任务落终态', () async {
    final m = build(
      error: const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN'),
    );
    final id1 = await m.submit(const GifSetting(), video);
    final id2 = await m.submit(const GifSetting(), video);
    final id3 = await m.submit(const GifSetting(), video);

    // 双槽下 1、2 并行失败 → 槽位释放 → 3 继续调度 → 全部 failed,无挂起
    await waitForState(id1, TaskState.failed);
    await waitForState(id2, TaskState.failed);
    await waitForState(id3, TaskState.failed);
    expect(service.convertCalls, hasLength(3), reason: '失败不阻塞后续调度');
  });

  test('重试并发:任务 1 重试成功,任务 2 全程并行', () async {
    final flaky = FakeFfmpegService(
      errorQueue: [const EncodeException(errorCode: 'GIF_1_ENCODE')],
    );
    final m = build(fake: flaky);
    final id1 = await m.submit(const GifSetting(), video);
    final id2 = await m.submit(const GifSetting(), video);

    await waitForState(id1, TaskState.completed);
    await waitForState(id2, TaskState.completed);
    expect((await repo.byId(id1))!.retryCount, 1);
    expect(flaky.convertCalls, hasLength(3), reason: 'id1 失败1次+重试1次,id2 1次');
  });

  test('取消退避中任务不复活(双启动回归锚点)', () async {
    // 第一个任务进入重试退避:先失败再退避,需要慢退避
    final slowService = FakeFfmpegService(
      errorQueue: [const EncodeException(errorCode: 'GIF_1_ENCODE')],
    );
    final m2 = TaskManager(
      taskRepository: repo,
      historyRepository: historyRepo,
      ffmpegService: slowService,
      platformAdapter: _TestAdapter(tempRoot.path),
      logger: logger,
      retryDelay: (d) =>
          Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final id = await m2.submit(const GifSetting(), video);
    // 等失败进入退避(状态 queued,retryCount=1)
    for (var i = 0; i < 100; i++) {
      final t = await repo.byId(id);
      if (t?.retryCount == 1 && t?.state == TaskState.queued) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // 退避期间取消
    await m2.cancel(id);
    await Future<void>.delayed(const Duration(milliseconds: 300)); // 退避窗口结束

    final t = await repo.byId(id);
    expect(t!.state, TaskState.cancelled, reason: '退避中取消后不复活');
    expect(slowService.convertCalls, hasLength(1), reason: '不二次启动');
  });

  test('取消 running → finally 自动填槽', () async {
    final m = build(blockNth: [1, 2, 3, 4]);
    final ids = <int>[];
    for (var i = 0; i < 4; i++) {
      ids.add(await m.submit(const GifSetting(), video));
    }
    await waitForCount(2);

    await m.cancel(ids[0]); // 取消一个 running
    // 放行被取消的转换(Fake 阻塞中需放行才检测令牌),槽位释放后补位
    service.unblock();
    for (var i = 0; i < 100; i++) {
      if (service.convertCalls.length >= 3) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(
      service.convertCalls.length,
      greaterThanOrEqualTo(3),
      reason: '取消后槽位释放并补位启动后续任务',
    );

    service.unblockAll();
    await waitForState(ids[0], TaskState.cancelled);
    for (var i = 1; i < 4; i++) {
      await waitForState(ids[i], TaskState.completed);
    }
  });

  test('cancelAll:2 running + 2 queued → 全 cancelled', () async {
    final m = build(blockNth: [1, 2]);
    final ids = <int>[];
    for (var i = 0; i < 4; i++) {
      ids.add(await m.submit(const GifSetting(), video));
    }
    await waitForCount(2);

    await m.cancelAll();

    service.unblockAll();
    for (final id in ids) {
      await waitForState(id, TaskState.cancelled);
    }
  });

  test('8 任务压力:状态无错乱,终态全收,无重复启动', () async {
    final m = build(blockNth: [1, 2]);
    final ids = <int>[];
    for (var i = 0; i < 8; i++) {
      ids.add(await m.submit(const GifSetting(), video));
    }
    await waitForCount(2);
    expect(service.convertCalls.toSet(), {ids[0], ids[1]});

    service.unblockAll();
    for (final id in ids) {
      await waitForState(id, TaskState.completed);
    }
    // 无重复启动:8 个任务恰 8 次调用(去重后仍 8)
    expect(service.convertCalls.toSet(), ids.toSet());
    expect(service.convertCalls.length, 8);
    // 历史 8 条
    final histories = await historyRepo.list();
    expect(histories, hasLength(8));
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

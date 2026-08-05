import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_history.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/exceptions/source_missing_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/history_repository.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/history/application/history_controller.dart';
import 'package:chameleon_gif/features/history/application/history_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [HistoryController] 测试(P5-WP3):加载/自动刷新/删除/清空/重转。
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
  late InMemoryHistoryRepository historyRepo;
  late FakeParseVideoPort parsePort;
  late _FakeService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    historyRepo = InMemoryHistoryRepository();
    service = _FakeService();
    parsePort = FakeParseVideoPort();
    final tempRoot = await Directory.systemTemp.createTemp('gifforge_hc_');
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(historyRepo),
        parseVideoPortProvider.overrideWithValue(parsePort),
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
    )..listen(historyControllerProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
  });

  HistoryController ctl() => container.read(historyControllerProvider.notifier);

  Future<List<ExportHistory>> stateList() async {
    for (var i = 0; i < 100; i++) {
      final v = container.read(historyControllerProvider).value;
      if (v != null) return v;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('历史状态未加载');
  }

  Future<void> waitForConvert(int n) async {
    for (var i = 0; i < 100; i++) {
      if (service.convertCalls.length >= n) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待转换调用超时: 期望 $n 实际 ${service.convertCalls.length}');
  }

  ExportHistory history(int day, {GifSetting? settings}) {
    return ExportHistory(
      id: day,
      videoPath: '/tmp/videos/demo.mp4',
      outputPath: '/tmp/gifforge_1/out.gif',
      settings: settings ?? const GifSetting(fps: 24, width: 320, loop: 2),
      durationMs: 1200,
      outputSizeBytes: 2048,
      createdAt: DateTime(2026, 1, day),
      sourceDurationMs: 10000,
      outputFrameCount: 150,
    );
  }

  test('初始加载:seed 历史按 createdAt 倒序进入状态', () async {
    await historyRepo.add(history(1));
    await historyRepo.add(history(3));
    await historyRepo.add(history(2));
    await ctl().reload();

    final list = await stateList();
    expect(list.map((h) => h.createdAt.day).toList(), [3, 2, 1]);
  });

  test('taskEvents completed → 自动 reload(端到端)', () async {
    await ctl().reload();
    expect(await stateList(), isEmpty);

    // 经真实 TaskManager 完成一个转换 → 历史自动出现
    final manager = container.read(taskManagerProvider);
    await manager.submit(const GifSetting(), video);
    for (var i = 0; i < 100; i++) {
      final list = container.read(historyControllerProvider).value;
      if (list != null && list.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final list = await stateList();
    expect(list, hasLength(1));
    expect(list.single.videoPath, video.path);
  });

  test('delete → 仓储移除且状态刷新', () async {
    final id = await historyRepo.add(history(1));
    await ctl().reload();

    await ctl().delete(id);

    expect(await historyRepo.byId(id), isNull);
    expect(await stateList(), isEmpty);
  });

  test('clear → 状态为空列表', () async {
    await historyRepo.add(history(1));
    await historyRepo.add(history(2));
    await ctl().reload();

    await ctl().clear();

    expect(await stateList(), isEmpty);
  });

  test('reload 仓储异常 → 状态置 error,不产生未处理异步错误', () async {
    final broken = _ThrowingHistoryRepository();
    final tempRoot = await Directory.systemTemp.createTemp('gifforge_hc2_');
    final container2 = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        appLoggerProvider.overrideWithValue(AppLogger()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(broken),
        parseVideoPortProvider.overrideWithValue(FakeParseVideoPort()),
        ffmpegServiceProvider.overrideWithValue(_FakeService()),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: broken,
            ffmpegService: ref.read(ffmpegServiceProvider),
            platformAdapter: ref.read(platformAdapterProvider),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    )..listen(historyControllerProvider, (_, _) {});

    // build 触发首次 reload,等待 error 状态(而非未处理异步错误)
    for (var i = 0; i < 100; i++) {
      final v = container2.read(historyControllerProvider);
      if (v.hasError) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container2.read(historyControllerProvider).hasError, isTrue,
        reason: '仓储异常应落到 AsyncValue.error');
    container2.dispose();
    await tempRoot.delete(recursive: true);
  });

  test('retry 成功:submit 被调用,settings 与历史快照全等', () async {
    final settings = const GifSetting(
      fps: 24,
      width: 640,
      start: Duration(seconds: 3),
      end: Duration(seconds: 9),
      loop: 2,
    );
    final id = await historyRepo.add(history(1, settings: settings));
    await ctl().reload();

    final newTaskId = await ctl().retry((await historyRepo.byId(id))!);
    await waitForConvert(1); // TaskManager 异步链

    expect(newTaskId, isNotNull);
    expect(service.convertCalls, hasLength(1));
    expect(service.lastSetting, settings, reason: '重转参数与历史快照全等');
    expect(service.lastVideo!.path, video.path);
  });

  test('retry 源文件缺失:透传 SourceMissingException,任务未创建', () async {
    parsePort.error = const SourceMissingException(
      errorCode: 'GIF_1_SOURCE_MISSING',
    );
    final id = await historyRepo.add(history(1));
    await ctl().reload();

    expect(
      () async => ctl().retry((await historyRepo.byId(id))!),
      throwsA(isA<SourceMissingException>()),
    );
    expect(service.convertCalls, isEmpty);
  });

  test('retry 重复点击防护:阻塞解析期间二次调用返回 null', () async {
    final blocker = Completer<VideoInfo>();
    parsePort.blocker = blocker;
    final id = await historyRepo.add(history(1));
    await ctl().reload();
    final h = (await historyRepo.byId(id))!;

    final f1 = ctl().retry(h);
    final f2 = ctl().retry(h);
    expect(f2, completion(isNull), reason: '重转中二次调用被拒');

    blocker.complete(video);
    await f1;
    await waitForConvert(1);
    expect(service.convertCalls, hasLength(1), reason: '仅创建一个任务');
  });

  test('retry 防御:start >= end 历史 → GIF_RETRY_INVALID', () async {
    final id = await historyRepo.add(
      history(
        1,
        settings: const GifSetting(
          start: Duration(seconds: 9),
          end: Duration(seconds: 3),
        ),
      ),
    );
    await ctl().reload();

    expect(
      () async => ctl().retry((await historyRepo.byId(id))!),
      throwsA(
        isA<FilePickException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_RETRY_INVALID',
        ),
      ),
    );
  });

  test('retry 0 时长参数放行(时长未知哨兵,与 export 同型守卫)', () async {
    final id = await historyRepo.add(
      history(
        1,
        settings: const GifSetting(start: Duration.zero, end: Duration.zero),
      ),
    );
    await ctl().reload();

    final newTaskId = await ctl().retry((await historyRepo.byId(id))!);
    await waitForConvert(1);

    expect(newTaskId, isNotNull, reason: 'end==0(时长未知)不应被拒绝');
    expect(service.convertCalls, hasLength(1));
  });

  test('retry 图片历史:直接 submitFromImages,不调 ffprobe', () async {
    const paths = ['/img/a.png', '/img/b.png'];
    final id = await historyRepo.add(
      ExportHistory(
        id: 9,
        videoPath: paths.first,
        imagePaths: paths,
        outputPath: '/tmp/gifforge_9/out.gif',
        settings: const GifSetting(frameDurationMs: 1000),
        durationMs: 1200,
        outputSizeBytes: 2048,
        createdAt: DateTime(2026, 1, 2),
        sourceDurationMs: 3000,
        outputFrameCount: 45,
      ),
    );
    await ctl().reload();

    final newTaskId = await ctl().retry((await historyRepo.byId(id))!);
    await waitForConvert(1); // TaskManager 异步链

    expect(newTaskId, isNotNull);
    expect(service.convertImagesCalls, hasLength(1));
    expect(
      service.receivedSources.single.paths,
      paths,
      reason: '以历史 imagePaths 重建源',
    );
    expect(parsePort.parseCalls, isEmpty, reason: '图片重转不调 ffprobe');
  });
}

class FakeParseVideoPort implements ParseVideoPort {
  Object? error;
  Completer<VideoInfo>? blocker;
  final parseCalls = <String>[];

  @override
  Future<VideoInfo> parse(String path) async {
    parseCalls.add(path);
    if (error != null) throw error!;
    if (blocker != null) return blocker!.future;
    return const VideoInfo(
      path: '/tmp/videos/demo.mp4',
      formatName: 'mp4',
      duration: Duration(seconds: 10),
      width: 640,
      height: 360,
      fps: 30,
      codec: 'h264',
    );
  }
}

class _FakeService implements FFmpegService {
  final convertImagesCalls = <int>[];
  final receivedSources = <ImageGifSource>[];

  @override
  Future<ConvertResult> convertImages({
    required ImageGifSource source,
    required GifSetting setting,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    convertImagesCalls.add(taskId);
    receivedSources.add(source);
    return convert(
      setting: setting,
      video: VideoInfo(
        path: source.paths.first,
        formatName: '',
        duration: Duration.zero,
        width: source.width,
        height: source.height,
        codec: '',
      ),
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  final convertCalls = <int>[];
  GifSetting? lastSetting;
  VideoInfo? lastVideo;

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
    lastSetting = setting;
    lastVideo = video;
    await File(outputPath).writeAsBytes(List.filled(123, 1));
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

/// 列表恒抛错的仓储(reload 容错测试)。
class _ThrowingHistoryRepository implements HistoryRepository {
  @override
  Future<int> add(ExportHistory history) async => 1;

  @override
  Future<void> delete(int id) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<ExportHistory>> list() async =>
      throw StateError('storage unavailable');

  @override
  Future<ExportHistory?> byId(int id) async => null;
}

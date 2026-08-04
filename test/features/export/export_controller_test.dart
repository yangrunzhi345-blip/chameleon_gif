import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/shared/providers/core_providers.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/encode_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_progress.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/export/application/export_controller.dart';
import 'package:gif_forge/features/export/application/export_providers.dart';
import 'package:gif_forge/features/export/application/export_state.dart';
import 'package:gif_forge/features/task_queue/application/task_manager.dart';
import 'package:gif_forge/features/task_queue/application/task_queue_providers.dart';
import 'package:gif_forge/shared/platform/platform_adapter.dart';
import 'package:gif_forge/shared/repositories/in_memory_history_repository.dart';
import 'package:gif_forge/shared/repositories/in_memory_task_repository.dart';

/// [ExportController] 测试(纯 Dart ProviderContainer,注入 Fake 服务)。
void main() {
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mov,mp4',
    duration: Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  late InMemoryTaskRepository taskRepo;
  late FakeExportService service;
  late Directory tempRoot;
  late ProviderContainer container;
  late _RecordingAdapter adapter;

  ProviderContainer build({Object? serviceError, FakeExportService? custom}) {
    service = custom ?? FakeExportService(error: serviceError);
    taskRepo = InMemoryTaskRepository();
    adapter = _RecordingAdapter(tempRoot.path);
    return ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepo),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        platformAdapterProvider.overrideWithValue(adapter),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: taskRepo,
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: service,
            platformAdapter: _TestAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    )..listen(exportControllerProvider, (_, _) {}); // 保持 autoDispose 存活
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('gifforge_export_');
  });

  tearDown(() async {
    container.dispose();
    await tempRoot.delete(recursive: true);
  });

  Future<ExportUiState> waitForLifecycle(ExportLifecycle want) async {
    for (var i = 0; i < 100; i++) {
      final s = container.read(exportControllerProvider);
      if (s.lifecycle == want) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail(
      '等待生命周期超时: $want,当前 ${container.read(exportControllerProvider).lifecycle}',
    );
  }

  test('submit:end 缺省装配为 video.duration,状态 idle → exporting', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    await ctl.submit(const GifSetting(), video);

    expect(
      container.read(exportControllerProvider).lifecycle,
      ExportLifecycle.exporting,
    );
    final tasks = await taskRepo.all();
    expect(tasks, hasLength(1));
    expect(tasks.single.settings.end, video.duration, reason: 'end 缺省装配源时长');
  });

  test('submit:start ≥ end 守卫拒绝,不入队', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    await ctl.submit(
      const GifSetting(start: Duration(seconds: 5), end: Duration(seconds: 5)),
      video,
    );

    final state = container.read(exportControllerProvider);
    expect(state.lifecycle, ExportLifecycle.failed);
    expect(state.errorMessage, contains('起点'));
    expect(await taskRepo.all(), isEmpty);
  });

  test('转换成功 → done 态(含输出大小)', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(const GifSetting(), video);

    final state = await waitForLifecycle(ExportLifecycle.done);
    expect(state.task?.state, TaskState.completed);
    expect(state.outputSizeBytes, 123);
  });

  test('转换失败 → failed 态(用户可读错误,不含原始路径)', () async {
    container = build(
      serviceError: const EncodeException(errorCode: 'GIF_1_ENCODE'),
    );
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(const GifSetting(), video);

    final state = await waitForLifecycle(ExportLifecycle.failed);
    expect(state.errorMessage, isNotEmpty);
    expect(state.errorMessage, isNot(contains('/tmp/')), reason: '不泄露路径');
    expect(state.errorMessage, isNot(contains('EncodeException')));
  });

  test('双提交守卫:连点 submit 只入队一个任务', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    final f1 = ctl.submit(const GifSetting(), video);
    final f2 = ctl.submit(const GifSetting(), video); // await 期间连点
    await f1;
    await f2;

    expect(await taskRepo.all(), hasLength(1), reason: '重入被守卫拒绝');
  });

  test('cancelTask 转发:running 任务取消 → cancelled 提示', () async {
    final blocked = FakeExportService(blockFirstConvert: true);
    container = build(custom: blocked);
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(const GifSetting(), video);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // 进入 running

    await ctl.cancelTask();
    blocked.unblock();

    final state = await waitForLifecycle(ExportLifecycle.failed);
    expect(state.errorMessage, contains('取消'));
  });

  test('reset → idle,可再次导出', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(const GifSetting(), video);
    await waitForLifecycle(ExportLifecycle.done);

    ctl.reset();
    expect(
      container.read(exportControllerProvider).lifecycle,
      ExportLifecycle.idle,
    );
  });

  test('openOutputFolder:done 态转发目录路径(不含文件名)', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(const GifSetting(), video);
    await waitForLifecycle(ExportLifecycle.done);

    await ctl.openOutputFolder();

    expect(adapter.openFolderCalls, hasLength(1));
    final dir = adapter.openFolderCalls.single;
    expect(dir, endsWith('/gifforge_1'), reason: '转发目录而非 out.gif 文件');
    expect(dir, isNot(endsWith('.gif')));
  });

  test('openOutputFolder:非 done 态静默跳过', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    await ctl.openOutputFolder(); // idle 无任务

    expect(adapter.openFolderCalls, isEmpty);
  });
}

/// 记录 openFolder 调用的平台适配器。
class _RecordingAdapter extends PlatformAdapter {
  _RecordingAdapter(this.tempRoot);

  final String tempRoot;
  final List<String> openFolderCalls = [];

  @override
  String get systemTempDir => tempRoot;

  @override
  Future<void> openFolder(String path) async {
    openFolderCalls.add(path);
  }
}

class FakeExportService implements FFmpegService {
  FakeExportService({this.error, this.blockFirstConvert = false});

  final Object? error;
  final bool blockFirstConvert;

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
    if (blockFirstConvert) {
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
        percent: 1.0,
        elapsed: const Duration(seconds: 1),
      ),
    );
    if (error != null) throw error!;
    // 真实写出输出文件,供 ExportController 完成态读取大小
    await File(outputPath).writeAsBytes(List.filled(123, 1));
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }

  Completer<void>? _blocker;

  void unblock() => _blocker?.complete();
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

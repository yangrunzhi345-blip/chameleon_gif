import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/encode_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/directory_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/export/application/export_controller.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/export/application/export_state.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer build({
    Object? serviceError,
    FakeExportService? custom,
    GallerySaveResult Function()? galleryResult,
  }) {
    service = custom ?? FakeExportService(error: serviceError);
    taskRepo = InMemoryTaskRepository();
    adapter = _RecordingAdapter(tempRoot.path);
    return ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        directoryPickPortProvider.overrideWithValue(_FakeDirPick(adapter)),
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
            platformAdapter: _TestAdapter(
              tempRoot.path,
              galleryResult: galleryResult,
            ),
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

  Future<ExportFormState> waitForLifecycle(ExportLifecycle want) async {
    for (var i = 0; i < 100; i++) {
      final s = container.read(exportControllerProvider);
      if (s.lifecycle == want) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail(
      '等待生命周期超时: $want,当前 ${container.read(exportControllerProvider).lifecycle}',
    );
  }

  test('updateHeight:钳制 0–4096 并清 formError', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    ctl.updateHeight(1080);
    expect(container.read(exportControllerProvider).height, 1080);
    // 超界钳制
    ctl.updateHeight(99999);
    expect(container.read(exportControllerProvider).height, 4096);
    // 0 = 原图等比
    ctl.updateHeight(0);
    expect(container.read(exportControllerProvider).height, 0);
  });

  test('submit:end 缺省装配为 video.duration,状态 idle → exporting', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    await ctl.submit(setting: const GifSetting(), video: video);

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
      setting: const GifSetting(
        start: Duration(seconds: 5),
        end: Duration(seconds: 5),
      ),
      video: video,
    );

    final state = container.read(exportControllerProvider);
    expect(state.lifecycle, ExportLifecycle.failed);
    expect(state.errorMessage, contains('起点'));
    expect(await taskRepo.all(), isEmpty);
  });

  test('转换成功 → done 态(含输出大小)', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);

    final state = await waitForLifecycle(ExportLifecycle.done);
    expect(state.task?.state, TaskState.completed);
    expect(state.outputSizeBytes, 123);
  });

  test('转换失败 → failed 态(用户可读错误,不含原始路径)', () async {
    container = build(
      serviceError: const EncodeException(errorCode: 'GIF_1_ENCODE'),
    );
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);

    final state = await waitForLifecycle(ExportLifecycle.failed);
    expect(state.errorMessage, isNotEmpty);
    expect(state.errorMessage, isNot(contains('/tmp/')), reason: '不泄露路径');
    expect(state.errorMessage, isNot(contains('EncodeException')));
  });

  test('双提交守卫:连点 submit 只入队一个任务', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    final f1 = ctl.submit(setting: const GifSetting(), video: video);
    final f2 = ctl.submit(
      setting: const GifSetting(),
      video: video,
    ); // await 期间连点
    await f1;
    await f2;

    expect(await taskRepo.all(), hasLength(1), reason: '重入被守卫拒绝');
  });

  test('cancelTask 转发:running 任务取消 → cancelled 提示', () async {
    final blocked = FakeExportService(blockFirstConvert: true);
    container = build(custom: blocked);
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // 进入 running

    await ctl.cancelTask();
    blocked.unblock();

    final state = await waitForLifecycle(ExportLifecycle.failed);
    expect(state.errorMessage, contains('取消'));
  });

  test('reset → idle,可再次导出', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);
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
    await ctl.submit(setting: const GifSetting(), video: video);
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

  test('openOutputFolder:已保存到相册 → 打开相册定位(而非文件夹)', () async {
    container = build(
      galleryResult: () => const GallerySaveResult.saved(
        displayPath: 'Pictures/GIFForge/demo.gif',
        uri: 'content://media/external/images/media/9',
      ),
    );
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);
    await waitForLifecycle(ExportLifecycle.done);

    await ctl.openOutputFolder();

    expect(adapter.openGalleryUris, [
      'content://media/external/images/media/9',
    ]);
    expect(adapter.openFolderCalls, isEmpty);
  });

  test('shareGif:转发输出文件到分享面板', () async {
    container = build(
      galleryResult: () => const GallerySaveResult.failed('系统版本过低'),
    );
    final ctl = container.read(exportControllerProvider.notifier);
    await ctl.submit(setting: const GifSetting(), video: video);
    await waitForLifecycle(ExportLifecycle.done);

    await ctl.shareGif();

    expect(adapter.shareFileCalls, hasLength(1));
    expect(adapter.shareFileCalls.single, endsWith('out.gif'));
  });

  test('reset:已保存到相册 → 删除私有副本;未保存 → 保留', () async {
    // 真实流完成(saved)后再重置 → 私有副本删除
    container = build(
      galleryResult: () => const GallerySaveResult.saved(
        displayPath: 'Pictures/GIFForge/demo.gif',
        uri: 'content://media/1',
      ),
    );
    final ctl2 = container.read(exportControllerProvider.notifier);
    await ctl2.submit(setting: const GifSetting(), video: video);
    final done = await waitForLifecycle(ExportLifecycle.done);
    final outputPath = done.task!.outputPath!;
    expect(File(outputPath).existsSync(), isTrue, reason: '弹窗期间保留');

    await ctl2.reset();
    expect(File(outputPath).existsSync(), isFalse, reason: 'reset 后私有副本删除');

    // 未保存(unsupported)→ 保留
    container = build();
    final ctl3 = container.read(exportControllerProvider.notifier);
    await ctl3.submit(setting: const GifSetting(), video: video);
    final done2 = await waitForLifecycle(ExportLifecycle.done);
    final kept = done2.task!.outputPath!;
    await ctl3.reset();
    expect(File(kept).existsSync(), isTrue, reason: '桌面/unsupported 不删');
  });

  test('pickOutputDir:成功 → 表单回填 + 默认目录持久化', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);
    adapter.pickResult = '${tempRoot.path}/my_gif';

    await ctl.pickOutputDir();

    final state = container.read(exportControllerProvider);
    expect(state.outputDir, '${tempRoot.path}/my_gif');
    expect(prefs.getString('default_export_dir'), '${tempRoot.path}/my_gif');
  });

  test('pickOutputDir:取消(null)静默,表单不变', () async {
    container = build();
    final ctl = container.read(exportControllerProvider.notifier);

    await ctl.pickOutputDir(); // pickResult 默认 null

    expect(container.read(exportControllerProvider).outputDir, isNull);
  });
}

/// 记录 openFolder 调用的平台适配器。
class _RecordingAdapter extends PlatformAdapter {
  _RecordingAdapter(this.tempRoot);

  final String tempRoot;
  final List<String> openFolderCalls = [];
  final List<String> openGalleryUris = [];
  final List<String> shareFileCalls = [];

  /// 目录选择结果(null = 取消)。
  String? pickResult;

  @override
  String get systemTempDir => tempRoot;

  @override
  Future<void> openFolder(String path) async {
    openFolderCalls.add(path);
  }

  @override
  Future<void> openGallery({String? uri}) async {
    openGalleryUris.add(uri ?? '');
  }

  @override
  Future<void> shareFile(String path) async {
    shareFileCalls.add(path);
  }
}

/// 目录选择端口替身(结果委托给 [_RecordingAdapter.pickResult])。
class _FakeDirPick implements DirectoryPickPort {
  _FakeDirPick(this.adapter);

  final _RecordingAdapter adapter;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async =>
      adapter.pickResult;
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
  _TestAdapter(this.tempRoot, {this.galleryResult});

  final String tempRoot;

  /// 可配置相册保存结果(null = unsupported)。
  final GallerySaveResult Function()? galleryResult;

  @override
  String get systemTempDir => tempRoot;

  @override
  Future<GallerySaveResult> saveToGallery(
    String sourcePath, {
    String? displayName,
  }) async => galleryResult?.call() ?? const GallerySaveResult.unsupported();
}

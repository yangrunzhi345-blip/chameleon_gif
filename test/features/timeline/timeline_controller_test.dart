import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/preview/application/preview_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/features/timeline/application/range_selection.dart';
import 'package:chameleon_gif/features/timeline/application/timeline_controller.dart';
import 'package:chameleon_gif/features/timeline/application/timeline_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';

/// [TimelineController] 状态机测试(docs/14 §14.3 时间轴用例)。
void main() {
  late ProviderContainer container;
  late FakePlayerPort port;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer buildContainer() {
    port = FakePlayerPort();
    return ProviderContainer(
      overrides: [
        previewPlayerPortProvider.overrideWithValue(port),
        // commitRange 联动导出表单,装配 export 链
        sharedPrefsProvider.overrideWithValue(prefs),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: _NoopFfmpegService(),
            platformAdapter: _TestAdapter(),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    )..listen(timelineControllerProvider, (_, _) {});
  }

  tearDown(() {
    container.dispose();
  });

  TimelineController ctl() =>
      container.read(timelineControllerProvider.notifier);

  RangeSelection sel() => container.read(timelineControllerProvider);

  const tenSec = Duration(seconds: 10);

  test('init:end 缺省取视频时长;自定义 start/end 生效', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    expect(sel().start, Duration.zero);
    expect(sel().end, tenSec);

    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 6),
    );
    expect(sel().start, const Duration(seconds: 2));
    expect(sel().end, const Duration(seconds: 6));
  });

  test('init:超界值钳制到 [0, 视频时长]', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: -1),
      end: const Duration(seconds: 99),
    );
    expect(sel().start, Duration.zero);
    expect(sel().end, tenSec);
  });

  test('init:start > end 自动交换', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 8),
      end: const Duration(seconds: 3),
    );
    expect(sel().start, const Duration(seconds: 3));
    expect(sel().end, const Duration(seconds: 8));
  });

  test('setRange:更新选区并钳制,不触发表单联动', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().setRange(
      start: const Duration(seconds: 3),
      end: const Duration(seconds: 9),
    );
    expect(sel().start, const Duration(seconds: 3));
    expect(sel().end, const Duration(seconds: 9));

    // 越界钳制
    ctl().setRange(
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 99),
    );
    expect(sel().end, tenSec);
  });

  test('commitRange:落选区;setStart/setEnd 交换后更新', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().commitRange(
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 7),
    );
    expect(sel().start, const Duration(seconds: 2));

    // 把起点设到终点之后 → 自动交换
    ctl().setStart(const Duration(seconds: 8));
    expect(sel().start, const Duration(seconds: 7));
    expect(sel().end, const Duration(seconds: 8));
  });

  test('seekPreview:尾缘 100ms 节流,连发只执行末次', () async {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().seekPreview(const Duration(seconds: 1));
    ctl().seekPreview(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(port.seekCalls, isEmpty, reason: '窗口内不 seek');

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(port.seekCalls, [const Duration(seconds: 2)], reason: '尾缘执行末次');
  });

  test('cancelPendingSeek:拖动结束取消未决 seek', () async {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);

    ctl().seekPreview(const Duration(seconds: 3));
    ctl().cancelPendingSeek();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(port.seekCalls, isEmpty, reason: '未决 seek 已取消');
  });

  test('重新 init(换视频)选区重置', () {
    container = buildContainer();
    ctl().init(
      videoDuration: tenSec,
      start: const Duration(seconds: 2),
      end: const Duration(seconds: 5),
    );
    ctl().init(
      videoDuration: const Duration(seconds: 3),
      start: const Duration(seconds: 1),
    );
    expect(sel().start, const Duration(seconds: 1));
    expect(sel().end, const Duration(seconds: 3));
  });

  test('commitRange 联动导出表单(syncRange)', () {
    container = buildContainer();
    ctl().init(videoDuration: tenSec);
    container
        .read(exportControllerProvider.notifier)
        .initForm(
          video: const VideoInfo(
            path: '/tmp/a.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );

    ctl().commitRange(
      start: const Duration(seconds: 3),
      end: const Duration(seconds: 8),
    );

    final form = container.read(exportControllerProvider);
    expect(form.start, const Duration(seconds: 3));
    expect(form.end, const Duration(seconds: 8));
  });

  // ---- 跨模块转发(B-3 批准:UI 只经本模块 provider 消费预览) ----

  test('previewReady:预览未加载 false,加载后 true', () async {
    container = buildContainer();
    // 保持 autoDispose 的 previewController 活跃(无 UI watch)
    container.listen(previewControllerProvider, (_, _) {});
    expect(ctl().previewReady, isFalse);

    await container
        .read(previewControllerProvider.notifier)
        .load(
          const VideoInfo(
            path: '/tmp/a.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(ctl().previewReady, isTrue);
  });

  test('togglePlayPause:播放中 → 暂停;停止 → 播放(经 preview 转发)', () async {
    container = buildContainer();
    // 保持 autoDispose 的 previewController 活跃(无 UI watch)
    container.listen(previewControllerProvider, (_, _) {});
    await container
        .read(previewControllerProvider.notifier)
        .load(
          const VideoInfo(
            path: '/tmp/a.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(port.pauseCount, 0);

    ctl().togglePlayPause(); // 播放中 → 暂停
    expect(port.pauseCount, 1);

    // 等 playingStream(false) 事件到达,状态归一下再切回
    await Future<void>.delayed(Duration.zero);
    expect(container.read(previewControllerProvider).isPlaying, isFalse);
    ctl().togglePlayPause(); // 已暂停 → 恢复播放
    expect(port.playCount, 1);
  });

  test('positionStream/durationStream 经转发可达(播放头数据)', () async {
    container = buildContainer();
    container.listen(previewControllerProvider, (_, _) {});
    await container
        .read(previewControllerProvider.notifier)
        .load(
          const VideoInfo(
            path: '/tmp/a.mp4',
            formatName: 'mp4',
            duration: Duration(seconds: 10),
            width: 640,
            height: 360,
            fps: 30,
            codec: 'h264',
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final positions = <Duration>[];
    final sub = ctl().positionStream.listen(positions.add);
    port.emitPosition(const Duration(seconds: 4));
    await Future<void>.delayed(const Duration(milliseconds: 300)); // 节流窗口
    expect(positions, contains(const Duration(seconds: 4)));
    await sub.cancel();
  });
}

class _NoopFfmpegService implements FFmpegService {
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
    throw UnimplementedError('本测试不执行导出');
  }
}

class _TestAdapter extends PlatformAdapter {
  @override
  String get systemTempDir => '/tmp/timeline_test';
}

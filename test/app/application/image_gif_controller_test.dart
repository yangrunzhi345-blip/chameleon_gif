import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/image_gif_controller.dart';
import 'package:chameleon_gif/app/application/image_gif_state.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/per_image_control.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_image_probe_port.dart';

/// [ImageGifController] 单测:探测透传/表单默认/提交守卫/生命周期。
void main() {
  late ProviderContainer container;
  late InMemoryTaskRepository taskRepo;
  late FakeImageProbePort probe;
  late _FakeConvertService service;
  late Directory tempRoot;
  late SharedPreferences prefs;

  ProviderContainer build({Object? probeError}) {
    probe = FakeImageProbePort(error: probeError);
    service = _FakeConvertService();
    taskRepo = InMemoryTaskRepository();
    return ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        imageProbePortProvider.overrideWithValue(probe),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
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
    )..listen(imageGifControllerProvider, (_, _) {});
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_imgc_');
  });

  tearDown(() {
    container.dispose();
    tempRoot.deleteSync(recursive: true);
  });

  ImageGifFormState state() => container.read(imageGifControllerProvider);

  Future<ImageGifFormState> waitLifecycle(ImageGifLifecycle lifecycle) async {
    for (var i = 0; i < 100; i++) {
      final s = state();
      if (s.lifecycle == lifecycle) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('等待生命周期超时: $lifecycle');
  }

  test('init 应用默认参数(frameDurationMs 默认 1000ms,usePalette 默认 true)', () {
    container = build();
    container.read(imageGifControllerProvider.notifier).init();

    final s = state();
    expect(s.fps, 15.0);
    expect(s.frameDurationMs, 1000);
    expect(s.usePalette, isTrue);
    expect(s.width, 0);
  });

  test('updatePaths:探测成功(640×480)后选 2 倍 → 联动 1280×960', () async {
    container = build();
    final ctl = container.read(imageGifControllerProvider.notifier);
    ctl.init();

    await ctl.updatePaths(['/tmp/img/a.png', '/tmp/img/b.png']);
    expect(probe.probeCalls, ['/tmp/img/a.png']);

    ctl.updateScaleMultiplier(2.0);
    expect(state().width, 1280);
    expect(state().height, 960);
    expect(state().scaleMultiplier, 2.0);
  });

  test('updatePaths:同一首图去重,不重复探测', () async {
    container = build();
    final ctl = container.read(imageGifControllerProvider.notifier);
    ctl.init();

    await ctl.updatePaths(['/tmp/img/a.png']);
    await ctl.updatePaths(['/tmp/img/a.png', '/tmp/img/c.png']);
    expect(probe.probeCalls, ['/tmp/img/a.png'], reason: '首路径不变 → 跳过');
  });

  test('updatePaths:探测失败 → 选倍数仅存偏好;恢复后联动回填', () async {
    container = build(probeError: StateError('decode failed'));
    final ctl = container.read(imageGifControllerProvider.notifier);
    ctl.init();

    await ctl.updatePaths(['/tmp/img/a.png']);
    // 探测失败:选倍数只存偏好,宽高重置 0(等待探测成功)
    ctl.updateScaleMultiplier(2.0);
    expect(state().scaleMultiplier, 2.0);
    expect(state().width, 0);

    // 探测恢复(更换图片)后联动回填
    probe.error = null;
    probe.width = 64;
    probe.height = 64;
    await ctl.updatePaths(['/tmp/img/b.png']);
    expect(state().width, 128, reason: '64×64 × 2');
    expect(state().height, 128);
  });

  test('init:持久化默认 (0,0,2.0) 继承倍数,updatePaths 后联动回填', () async {
    prefs.setString(
      'default_gif_setting',
      '{"fps":15,"width":0,"height":0,"loop":0,"start":0,'
          '"end":null,"frameDurationMs":null,"usePalette":true,'
          '"scaleMultiplier":2.0}',
    );
    container = build();
    final ctl = container.read(imageGifControllerProvider.notifier);
    ctl.init();
    expect(state().scaleMultiplier, 2.0);

    probe.width = 64;
    probe.height = 64;
    await ctl.updatePaths(['/tmp/img/a.png']);
    expect(state().width, 128);
    expect(state().height, 128);
  });

  test('submit:探测首图尺寸并透传给源,状态 → exporting', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(const ['/img/a.png', '/img/b.png']);

    expect(probe.probeCalls, ['/img/a.png'], reason: '探测首图');
    final s = await waitLifecycle(ImageGifLifecycle.exporting);
    expect(s.taskId, isNotNull);
    final tasks = await taskRepo.all();
    expect(tasks.single.imagePaths, ['/img/a.png', '/img/b.png']);
    // 经 TaskManager 缓存 → 由 _FakeConvertService 收到的源断言尺寸透传;
    // 转换异步执行,等待 done(源已消费)后断言
    await waitLifecycle(ImageGifLifecycle.done);
    expect(service.receivedSources.single.width, 640);
    expect(service.receivedSources.single.height, 480);
  });

  test('submit 带每图控制:归一化后透传给源', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(
      const ['/img/a.png', '/img/b.png'],
      perImageControls: [
        PerImageControl(scaleMultiplier: 2),
        PerImageControl(width: 480, height: 480),
      ],
    );
    await waitLifecycle(ImageGifLifecycle.done);
    expect(service.receivedSources.single.perImageControls, const [
      PerImageControl(scaleMultiplier: 2),
      PerImageControl(width: 480, height: 480),
    ]);
    // 任务持久化同样携带(恢复/重转复现)
    final tasks = await taskRepo.all();
    expect(tasks.single.perImageControls, hasLength(2));
  });

  test('submit 每图控制部分为 null:补齐为默认值对象', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(
      const ['/img/a.png', '/img/b.png'],
      perImageControls: [null, PerImageControl(width: 320)],
    );
    await waitLifecycle(ImageGifLifecycle.done);
    expect(service.receivedSources.single.perImageControls, const [
      PerImageControl(),
      PerImageControl(width: 320),
    ]);
  });

  test('submit 每图控制全部默认 → null(不产生控制/不持久化)', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(
      const ['/img/a.png', '/img/b.png'],
      perImageControls: [
        PerImageControl(),
        PerImageControl(scaleMultiplier: 1.0),
      ],
    );
    await waitLifecycle(ImageGifLifecycle.done);
    expect(service.receivedSources.single.perImageControls, isNull);
    final tasks = await taskRepo.all();
    expect(tasks.single.perImageControls, isNull);
  });

  test('探测失败 → formError 拦截,不入队', () async {
    container = build(probeError: StateError('decode failed'));
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(const ['/img/a.png']);

    expect(state().formError, contains('无法读取首图尺寸'));
    expect(state().lifecycle, ImageGifLifecycle.idle, reason: '不入队');
    expect(await taskRepo.all(), isEmpty);
  });

  test('空列表拒绝', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(const []);

    expect(state().formError, contains('请先选择图片'));
    expect(await taskRepo.all(), isEmpty);
  });

  test('updateFrameDurationMs:低于帧率下限 → formError,合法值生效', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    notifier.updateFrameDurationMs(20); // 15fps 下限 67ms
    expect(state().formError, contains('每张图片停留时长'));

    notifier.updateFrameDurationMs(500);
    expect(state().frameDurationMs, 500);
    expect(state().formError, isNull);
  });

  test('updatePlaybackSpeed:钳制 0.25–4,合法值生效', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    notifier.updatePlaybackSpeed(8); // 超上限 → 钳 4
    expect(state().playbackSpeed, 4);

    notifier.updatePlaybackSpeed(0.1); // 低下限 → 钳 0.25
    expect(state().playbackSpeed, 0.25);

    notifier.updatePlaybackSpeed(2);
    expect(state().playbackSpeed, 2);
    expect(state().formError, isNull);
  });

  test('tryUpdateFrameDurationMs:非数字/越界 → 错误并返回 false,合法 → true', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    expect(notifier.tryUpdateFrameDurationMs('abc'), isFalse);
    expect(state().formError, contains('须为数字'));

    expect(notifier.tryUpdateFrameDurationMs('99999'), isFalse);
    expect(state().formError, contains('需在'));

    expect(notifier.tryUpdateFrameDurationMs('500'), isTrue);
    expect(state().frameDurationMs, 500);
    expect(state().formError, isNull);
  });

  test('tryUpdateLoop:非数字 → 错误并返回 false;合法 → true', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    expect(notifier.tryUpdateLoop('abc'), isFalse);
    expect(state().formError, contains('循环次数'));

    expect(notifier.tryUpdateLoop('5'), isTrue);
    expect(state().loop, 5);
    expect(state().formError, isNull);
  });

  test('短路契约:try* 失败返回 false 且错误保留,调用方必须失败即停', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    final ok = notifier.tryUpdateFrameDurationMs('99999');
    expect(ok, isFalse);
    expect(state().formError, isNotNull);
    // try* 成功后照常清错(单字段输入修正);批处理(fetch flush)的"前错
    // 不清"由调用方短路保证:任一 false 立即停,不得继续调后项 ——
    // image_gif_screen._flushTextFields 已实现,越界场景由 widget 测试
    // 「越界 99999 不回车」覆盖(旧 bug:updateLoop 成功清掉越界错误 →
    // 静默用旧值转换)
  });

  test('tryUpdateCustomWidth/Height/ScaleMultiplier:越界 → false,合法 → true', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    expect(notifier.tryUpdateCustomWidth('0'), isFalse);
    expect(notifier.tryUpdateCustomWidth('150'), isTrue);
    expect(state().width, 150);

    expect(notifier.tryUpdateCustomHeight('9999'), isFalse);
    expect(notifier.tryUpdateCustomHeight('100'), isTrue);
    expect(state().height, 100);

    expect(notifier.tryUpdateCustomScaleMultiplier('0'), isFalse);
    expect(notifier.tryUpdateCustomScaleMultiplier('2'), isTrue);
    expect(state().scaleMultiplier, 2);
  });

  test('updateFps 联动每图时长下限自动抬升', () {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();
    notifier.updateFrameDurationMs(80); // 15fps 下限 67 → 合法

    notifier.updateFps(60); // 下限 17ms
    expect(state().fps, 60);
    expect(state().frameDurationMs, 80, reason: '合法值不被抬升');

    notifier.updateFrameDurationMs(10); // 60fps 下限 17 → 非法
    expect(state().formError, isNotNull);
  });

  test('submit 重入守卫:连点只入队一个任务', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();
    final f1 = notifier.submit(const ['/img/a.png']);
    final f2 = notifier.submit(const ['/img/b.png']);
    await Future.wait([f1, f2]);
    // 仅第一个提交生效(第二个被 _submitting 守卫拦截)
    final tasks = await taskRepo.all();
    expect(tasks, hasLength(1));
  });

  test('转换成功 → done 态(含输出大小),reset 回 idle', () async {
    container = build();
    final notifier = container.read(imageGifControllerProvider.notifier);
    notifier.init();

    await notifier.submit(const ['/img/a.png']);
    final done = await waitLifecycle(ImageGifLifecycle.done);
    expect(done.task, isNotNull);
    expect(done.outputSizeBytes, 123);

    await notifier.reset();
    expect(state().lifecycle, ImageGifLifecycle.idle);
  });
}

// ---- 测试替身 ----

class _FakeConvertService implements FFmpegService {
  final receivedSources = <ImageGifSource>[];

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
    await File(outputPath).writeAsBytes(List.filled(123, 1));
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }

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
    receivedSources.add(source);
    await File(outputPath).writeAsBytes(List.filled(123, 1));
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 1),
    width: 64,
    height: 64,
    fps: 15,
    codec: 'h264',
  );
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

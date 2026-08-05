import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/platform/process_engine.dart';
import 'package:chameleon_gif/shared/platform/process_ffprobe_executor.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures/fake_player_port.dart';

/// P7/P8 性能基准采集(需桌面环境 + 系统 ffmpeg,**profile 模式跑**):
///   flutter test -d linux --profile integration_test/perf_benchmark_test.dart
///
/// 输出 JSON lines(`PERF {...}`,metric/value),执行者抄入 docs/17 性能基线。
/// 采集项:
/// - 转码中 UI 帧率:FramePolicy.benchmarkLive + addTimingsCallback
///   (实测帧间隔 → fps;debug 数值仅参考,profile 才代表发布形态)
/// - 内存三点:VmRSS idle / 单任务转码 / 双并发转码 + VmHWM 全程峰值
///   (读 /proc/self/status,零依赖)
/// - 500MB 折算:双并发峰值 − idle 基线 = 每槽解码内存,按目标分辨率
///   线性放大折算(如 1080p ≈ 8× 320x240);真实 500MB 验证归 P9 打包冒烟
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 实时连续推帧:集成绑定默认按需推帧,无法测真实渲染帧率
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

  const clipPath = 'test/fixtures/videos/clip_long.mp4';
  // 加码参数:10s 320x240 → 640 宽 30fps,单任务编码 ≥5s 制造测量窗口
  const heavySetting = GifSetting(fps: 30, width: 640);

  late Directory tempRoot;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('gifforge_perf_');
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(_NoopFilePickPort()),
        parseVideoPortProvider.overrideWithValue(
          FfprobeParseVideoPort(
            executor: const ProcessFfprobeExecutor(),
            logger: AppLogger(),
          ),
        ),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegEngineProvider.overrideWithValue(const ProcessEngine()),
        ffmpegServiceProvider.overrideWithValue(
          FfmpegServiceEngine(
            engine: const ProcessEngine(),
            logger: AppLogger(),
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tempRoot.delete(recursive: true);
  });

  /// /proc/self/status 字段(如 VmRSS / VmHWM),KB;读取失败返回 -1。
  int procStatusKb(String key) {
    try {
      final status = File('/proc/self/status').readAsStringSync();
      for (final line in status.split('\n')) {
        if (line.startsWith('$key:')) {
          return int.parse(line.split(RegExp(r'\s+'))[1]);
        }
      }
    } on Object {
      // 非 Linux / 权限受限:返回 -1,由调用方记录
    }
    return -1;
  }

  void emit(String metric, num value, {Map<String, Object?>? extra}) {
    debugPrint(
      'PERF ${jsonEncode({'metric': metric, 'value': value, 'env': 'linux/${kProfileMode
          ? 'profile'
          : kReleaseMode
          ? 'release'
          : 'debug'}', ...?extra})}',
    );
  }

  /// 等待 running 数达到 [runningCount](0 时另需全部终态)。
  Future<void> waitState(
    WidgetTester tester,
    int runningCount, {
    required String reason,
    int timeoutSeconds = 120,
  }) async {
    final repo = container.read(taskRepositoryProvider);
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      final tasks = await repo.all();
      final running = tasks.where((t) => t.state == TaskState.running).length;
      final settled = tasks.every((t) => t.state.isFinal);
      if (running == runningCount && (runningCount > 0 || settled)) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    fail('等待超时: $reason');
  }

  testWidgets('性能基准:转码中帧率 + 内存三点 + 峰值', (tester) async {
    final video = VideoInfo(
      path: '${Directory.current.path}/$clipPath',
      formatName: 'mp4',
      duration: const Duration(seconds: 10),
      width: 320,
      height: 240,
      fps: 24,
      codec: 'h264',
    );
    final repo = container.read(taskRepositoryProvider);
    final controller = container.read(taskQueueControllerProvider.notifier);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await waitState(tester, 0, reason: '首帧就绪', timeoutSeconds: 10);

    // ① idle 基线(未转码)
    final idleRss = procStatusKb('VmRSS');
    emit('perf_idle_rss_kb', idleRss);

    // ② 单任务转码中
    await controller.submit(heavySetting, video);
    await waitState(tester, 1, reason: '单任务进入转码');
    await tester.pump(const Duration(milliseconds: 300));
    final singleRss = procStatusKb('VmRSS');
    emit('perf_single_rss_kb', singleRss);

    // ③ 双并发转码中 + 帧率采集窗口
    await controller.submit(heavySetting, video);
    await waitState(tester, 2, reason: '双任务并发转码');
    final frameTimings = <FrameTiming>[];
    void collect(List<FrameTiming> timings) => frameTimings.addAll(timings);
    SchedulerBinding.instance.addTimingsCallback(collect);
    await tester.pump(const Duration(milliseconds: 300));
    final bothRss = procStatusKb('VmRSS');
    emit('perf_concurrent_rss_kb', bothRss);

    // ④ 转码期间持续 pump(不 pumpAndSettle:进度流永不 settle)
    await waitState(tester, 0, reason: '双任务转码完成');
    SchedulerBinding.instance.removeTimingsCallback(collect);

    // ⑤ 全程峰值(VmHWM 单调,反映本进程最坏驻留)
    final peakRss = procStatusKb('VmHWM');
    emit('perf_peak_rss_kb', peakRss);

    // ⑥ 帧率:实测帧间隔(仅统计 build 阶段时间戳差分中位数)
    if (frameTimings.length >= 2) {
      final stamps = [
        for (final t in frameTimings)
          t.timestampInMicroseconds(FramePhase.buildStart),
      ];
      stamps.sort();
      final gaps = <int>[];
      for (var i = 1; i < stamps.length; i++) {
        gaps.add(stamps[i] - stamps[i - 1]);
      }
      gaps.sort();
      final medianGapUs = gaps[gaps.length ~/ 2];
      final fps = 1e6 / medianGapUs;
      emit('perf_ui_fps', fps, extra: {'frames': frameTimings.length});
    } else {
      emit('perf_ui_fps', -1, extra: {'frames': frameTimings.length});
    }

    // 折算参考:每槽解码内存(双并发 − idle),按 320x240 基准
    final perSlot = bothRss - idleRss;
    emit(
      'perf_decode_per_slot_kb_ref',
      perSlot,
      extra: {'scaling': '线性放大折算:1080p≈8×(320x240) 需真机验证,归 P9'},
    );

    // 宽松断言:转码完成 + 帧数据非空(性能数值不设硬门槛,记录为准)
    expect(
      (await repo.all()).map((t) => t.state),
      everyElement(TaskState.completed),
    );
    expect(frameTimings, isNotEmpty, reason: '应采集到帧时序数据');
    expect(idleRss, greaterThan(0), reason: '/proc 可读(Linux)');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _NoopFilePickPort implements FilePickPort {
  @override
  Future<List<String>?> pickImages() async => null;
  @override
  Future<String?> pickMp4() async => null;

  @override
  Future<List<String>?> pickMp4s() async => null;
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

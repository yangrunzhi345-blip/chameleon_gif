import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/application/providers.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/platform/process_engine.dart';
import 'package:chameleon_gif/shared/platform/process_ffprobe_executor.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/isar_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/isar_task_repository.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_history_schema.dart';
import 'package:chameleon_gif/shared/repositories/schemas/export_task_schema.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures/fake_camera_port.dart';
import '../test/fixtures/fake_player_port.dart';
import '../test/fixtures/fake_screen_recorder_port.dart';
import '../test/fixtures/fake_settings_repository.dart';
import '../test/fixtures/isar_test_helper.dart';

/// 采集衔接层集成测试(docs/20 阶段 A 阶段门;需桌面环境 + 系统 ffmpeg):
///   flutter test -d linux integration_test/capture_flow_test.dart
///
/// 真实链路:fake 采集(夹具按素材命名落盘 capturesDir)→ CaptureImportUseCase
/// (真实 ffprobe 解析)→ onImported 自动推 /preview → 轻参数真实转换
/// (ProcessEngine + 系统 ffmpeg)→ 输出 GIF8。**只 fake 采集设备本身**,
/// 解析/预览/转换全真实,构成"采集→导入→导出"集成语义。
///
/// 注意:转码期间进度流持续触发重建,**禁用 pumpAndSettle**,统一用
/// 显式 pump + 真实延时轮询(IntegrationTestWidgetsFlutterBinding live 时钟)。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 轻参数单遍:小夹具 + 320 宽 15fps,秒级完成(两遍调色板无必要)。
  const kLightSetting = GifSetting(fps: 15, width: 320, usePalette: false);

  const kFixtureVideo = 'test/fixtures/videos/clip_a.mp4';

  late Directory tempRoot;
  late Isar isar;
  late IsarTaskRepository taskRepo;
  late ProviderContainer container;
  late _TestAdapter adapter;
  late FakeCameraPort cameraPort;
  late FakeScreenRecorderPort recorderPort;

  setUpAll(initIsarNative);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('gifforge_capture_');
    isar = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: tempRoot.path);
    taskRepo = IsarTaskRepository(isar, logger: AppLogger());
    adapter = _TestAdapter(tempRoot.path);
    cameraPort = FakeCameraPort();
    recorderPort = FakeScreenRecorderPort();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(
          FfprobeParseVideoPort(
            executor: const ProcessFfprobeExecutor(),
            logger: AppLogger(),
          ),
        ),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        historyRepositoryProvider.overrideWithValue(
          IsarHistoryRepository(isar, logger: AppLogger()),
        ),
        ffmpegEngineProvider.overrideWithValue(const ProcessEngine()),
        ffmpegServiceProvider.overrideWithValue(
          FfmpegServiceEngine(
            engine: const ProcessEngine(),
            logger: AppLogger(),
          ),
        ),
        // taskManagerProvider 不 override:走默认装配(读上述注入)
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    if (isar.isOpen) {
      await isar.close();
    }
    await tempRoot.delete(recursive: true);
  });

  /// 轮询等待条件(真实延时 + 显式 pump;超时 fail)。
  Future<void> waitFor(
    WidgetTester tester,
    Future<bool> Function() cond, {
    required String reason,
    int timeoutSeconds = 60,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    while (DateTime.now().isBefore(deadline)) {
      if (await cond()) return;
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    fail('等待超时(${timeoutSeconds}s): $reason');
  }

  /// fake 采集行为:夹具视频按素材命名规范落盘 capturesDir,返回真实路径。
  Future<CaptureResult> captureFixture() async {
    final src = File('${Directory.current.path}/$kFixtureVideo');
    final dir = Directory(adapter.capturesDir)..createSync(recursive: true);
    final dst = File(
      '${dir.path}/${buildCaptureFilename(DateTime(2026, 8, 6, 12, 0, 0))}',
    );
    await src.copy(dst.path);
    return CaptureResult(finalPath: dst.path, durationMs: 5000);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // 带 rootNavigatorKey:自动导入的 onImported push 经此 key 生效
        child: ChameleonGifApp(
          router: GoRouter(
            routes: buildRoutes(),
            navigatorKey: rootNavigatorKey,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    '拍摄链:fake 采集 → 自动导入 /preview → 真实转换输出 GIF8',
    (tester) async {
      await pumpApp(tester);

      // 1. fake 采集(夹具按素材命名落盘)
      cameraPort.onCapture = (params, token) => captureFixture();
      final result = await cameraPort.capture(params: const CaptureParams());
      expect(result.finalPath, isNotEmpty);

      // 2. 自动导入:真实 ffprobe 解析 → onImported push /preview
      final video = await container
          .read(captureImportUseCaseProvider)
          .execute(result.finalPath, source: CaptureSource.camera);
      await waitFor(
        tester,
        () async => find.byType(PreviewScreen).evaluate().isNotEmpty,
        reason: '自动导入应进入预览工作台',
        timeoutSeconds: 30,
      );

      // 3. 轻参数真实转换(单遍;预览页停留,不经 UI 提交)
      await container
          .read(taskQueueControllerProvider.notifier)
          .submit(kLightSetting, video);

      // 4. 轮询至终态 → 输出 GIF8
      await waitFor(
        tester,
        () async {
          final tasks = await taskRepo.all();
          return tasks.isNotEmpty && tasks.every((t) => t.state.isFinal);
        },
        reason: '转换任务应完成',
        timeoutSeconds: 120,
      );
      final done = (await taskRepo.all()).singleWhere(
        (t) => t.state == TaskState.completed,
      );
      final bytes = await File(done.outputPath!).readAsBytes();
      expect(
        String.fromCharCodes(bytes.take(4)),
        'GIF8',
        reason: '输出应为可解码 GIF',
      );

      // 5. fake 调用记录与传入参数
      expect(cameraPort.captureCalls, hasLength(1));
      expect(cameraPort.captureCalls.single.fps, 15.0);
      expect(cameraPort.captureCalls.single.maxDurationMs, 30000);
      expect(recorderPort.recordCalls, isEmpty, reason: '拍摄链不触录屏端口');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    '录屏链:fake 录制 → 自动导入 /preview → 真实转换输出 GIF8',
    (tester) async {
      await pumpApp(tester);

      // 1. fake 录制(夹具按素材命名落盘)
      recorderPort.onRecord = (params, token) => captureFixture();
      final result = await recorderPort.record(params: const RecordParams());
      expect(result.finalPath, isNotEmpty);

      // 2. 自动导入(与拍摄共用同一用例链路)
      final video = await container
          .read(captureImportUseCaseProvider)
          .execute(result.finalPath, source: CaptureSource.camera);
      await waitFor(
        tester,
        () async => find.byType(PreviewScreen).evaluate().isNotEmpty,
        reason: '自动导入应进入预览工作台',
        timeoutSeconds: 30,
      );

      // 3. 轻参数真实转换
      await container
          .read(taskQueueControllerProvider.notifier)
          .submit(kLightSetting, video);

      // 4. 轮询至终态 → 输出 GIF8
      await waitFor(
        tester,
        () async {
          final tasks = await taskRepo.all();
          return tasks.isNotEmpty && tasks.every((t) => t.state.isFinal);
        },
        reason: '转换任务应完成',
        timeoutSeconds: 120,
      );
      final done = (await taskRepo.all()).singleWhere(
        (t) => t.state == TaskState.completed,
      );
      final bytes = await File(done.outputPath!).readAsBytes();
      expect(
        String.fromCharCodes(bytes.take(4)),
        'GIF8',
        reason: '输出应为可解码 GIF',
      );

      // 5. fake 调用记录与传入参数
      expect(recorderPort.recordCalls, hasLength(1));
      expect(recorderPort.recordCalls.single.fps, 15.0);
      expect(recorderPort.recordCalls.single.maxDurationMs, 60000);
      expect(cameraPort.captureCalls, isEmpty, reason: '录屏链不触拍摄端口');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;

  @override
  String capturesRoot() => '$tempRoot/captures';
}

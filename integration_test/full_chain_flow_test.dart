import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';
import 'package:chameleon_gif/features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'package:chameleon_gif/features/history/presentation/history_page.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/presentation/queue_page.dart';
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

import '../test/fixtures/fake_player_port.dart';
import '../test/fixtures/isar_test_helper.dart';

/// P8 全链路集成测试(UI 驱动 + 真实引擎,需桌面环境 + 系统 ffmpeg):
///   flutter test -d linux integration_test/full_chain_flow_test.dart
///
/// 真实链路:批量导入(3 夹具)→ 双槽并发(2 running + 1 queued)→
/// 单任务取消(clip_long)→ 自动入库(2 completed + 1 cancelled)→ 历史页 2 行。
/// 全部真实实现:Isar 临时实例、ProcessEngine + 系统 ffmpeg、ffprobe 解析;
/// 仅 filePickPort 注入多选路径(文件对话框无法自动化)。
///
/// 注意:转码期间进度流每 200ms 触发重建,**禁用 pumpAndSettle**,统一用
/// 显式 pump + 真实延时轮询(IntegrationTestWidgetsFlutterBinding 为 live
/// 时钟,真实异步可完成)。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const kFixtures = [
    'test/fixtures/videos/clip_a.mp4',
    'test/fixtures/videos/clip_long.mp4',
    'test/fixtures/videos/clip_b.mp4',
  ];

  late Directory tempRoot;
  late Isar isar;
  late IsarTaskRepository taskRepo;
  late IsarHistoryRepository historyRepo;
  late ProviderContainer container;
  late _FakeFilePickPort pickPort;

  setUpAll(initIsarNative);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('gifforge_chain_');
    isar = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
    ], directory: tempRoot.path);
    taskRepo = IsarTaskRepository(isar, logger: AppLogger());
    historyRepo = IsarHistoryRepository(isar, logger: AppLogger());
    pickPort = _FakeFilePickPort();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(pickPort),
        parseVideoPortProvider.overrideWithValue(
          FfprobeParseVideoPort(
            executor: const ProcessFfprobeExecutor(),
            logger: AppLogger(),
          ),
        ),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(taskRepo),
        historyRepositoryProvider.overrideWithValue(historyRepo),
        ffmpegEngineProvider.overrideWithValue(const ProcessEngine()),
        ffmpegServiceProvider.overrideWithValue(
          FfmpegServiceEngine(
            engine: const ProcessEngine(),
            logger: AppLogger(),
          ),
        ),
        // taskManagerProvider 不 override:走默认装配,复现真实崩溃恢复链路
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
      if (await cond()) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    fail('等待超时(${timeoutSeconds}s): $reason');
  }

  testWidgets(
    '批量导入 → 双槽并发 → 取消单任务 → 自动入库 → 历史页 2 行',
    (tester) async {
      // 1. 启动 app(显式容器 + 真实装配)
      pickPort.paths = [
        for (final f in kFixtures) '${Directory.current.path}/$f',
      ];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // 2. 批量导入 → 跳转队列页
      await tester.tap(find.text('批量导入'));
      await waitFor(
        tester,
        () async => find.byType(QueuePage).evaluate().isNotEmpty,
        reason: '批量导入后应跳转队列页',
        timeoutSeconds: 30,
      );

      // 3. 双槽并发:2 running + 1 queued
      await waitFor(
        tester,
        () async {
          final tasks = await taskRepo.all();
          return tasks.where((t) => t.state == TaskState.running).length == 2 &&
              tasks.where((t) => t.state == TaskState.queued).length == 1;
        },
        reason: '3 任务应 2 并发 + 1 排队',
        timeoutSeconds: 60,
      );

      // 4. 取消运行中的 clip_long(UI 层点行内取消按钮)
      await tester.pump(const Duration(milliseconds: 100));
      final longTile = find.widgetWithText(ListTile, 'clip_long.mp4');
      expect(longTile, findsOneWidget, reason: 'clip_long 行应可见');
      final cancelBtn = find.descendant(
        of: longTile,
        matching: find.byTooltip('取消'),
      );
      await tester.tap(cancelBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // 5. 终态:2 completed + 1 cancelled(取消不阻塞排队任务顶上)
      await waitFor(
        tester,
        () async {
          final tasks = await taskRepo.all();
          final states = {for (final t in tasks) t.state};
          return states.contains(TaskState.cancelled) &&
              states.where((s) => s == TaskState.completed).length == 2 &&
              tasks.every((t) => t.state.isFinal);
        },
        reason: '全部终态:2 completed + 1 cancelled',
        timeoutSeconds: 60,
      );

      // 6. 历史自动入库:completed 2 条,cancelled 不入
      await waitFor(
        tester,
        () async => (await historyRepo.list()).length == 2,
        reason: '历史应恰 2 条(完成入库,取消不入)',
        timeoutSeconds: 30,
      );

      // 7. 历史页渲染 2 行(真实 Isar + 真实缩略图抽帧)
      GoRouter.of(tester.element(find.byType(QueuePage))).push('/history');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HistoryPage), findsOneWidget);
      await waitFor(
        tester,
        () async =>
            find.widgetWithText(ListTile, 'clip_a.mp4').evaluate().isNotEmpty,
        reason: '历史页应显示 clip_a 行',
        timeoutSeconds: 30,
      );
      expect(find.widgetWithText(ListTile, 'clip_b.mp4'), findsOneWidget);

      // 8. 断言输出产物真实存在(GIF 头)
      final history = await historyRepo.list();
      for (final h in history) {
        final out = File(h.outputPath);
        expect(out.existsSync(), isTrue, reason: '输出文件存在');
        final bytes = await out.readAsBytes();
        expect(
          String.fromCharCodes(bytes.take(4)),
          'GIF8',
          reason: '输出可解码 GIF',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _FakeFilePickPort implements FilePickPort {
  List<String> paths = [];

  @override
  Future<String?> pickMp4() async => paths.isEmpty ? null : paths.first;

  @override
  Future<List<String>?> pickMp4s() async => paths;
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

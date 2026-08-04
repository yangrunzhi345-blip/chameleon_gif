import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/domain/repository_interfaces/task_repository.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/features/task_queue/presentation/queue_page.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_ffmpeg_service.dart';

/// [QueuePage] 交互测试(P6-WP2,§14.4 队列列表)。
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

  late SharedPreferences prefs;
  late InMemoryTaskRepository repo;
  late FakeFfmpegService service;
  late Directory tempRoot;

  Future<int> seedTask(TaskState state) async {
    return repo.add(
      ExportTask(
        id: 0,
        videoPath: video.path,
        settings: const GifSetting(),
        state: state,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = InMemoryTaskRepository();
    service = FakeFfmpegService(blockNthConvert: [1]);
    tempRoot = await Directory.systemTemp.createTemp('gifforge_qp_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Widget wrap() {
    return ProviderScope(
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
          (ref) => _StaticTaskManager(
            repo: repo,
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: service,
            platformAdapter: _TestAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: const MaterialApp(home: QueuePage()),
    );
  }

  testWidgets('空态:无任务 → 引导文案,全部取消禁用', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('暂无进行中的任务'), findsOneWidget);
    final cancelAll = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.stop_circle_outlined),
    );
    expect(cancelAll.onPressed, isNull);
  });

  testWidgets('渲染:running(进度条)/queued/failed 行与汇总', (tester) async {
    // 预置:1 running(fake 阻塞)+ 1 queued + 1 failed
    await seedTask(TaskState.running);
    await seedTask(TaskState.queued);
    await seedTask(TaskState.failed);

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 静态 manager(不执行任务),seed 状态直接展示:running+queued+failed
    expect(find.text('demo.mp4'), findsNWidgets(3));
    expect(find.textContaining('执行中 1'), findsOneWidget);
    expect(
      find.byType(LinearProgressIndicator),
      findsOneWidget,
      reason: 'running 行进度条',
    );
    expect(find.byIcon(Icons.refresh), findsOneWidget, reason: 'failed 行重试');
    expect(
      find.byIcon(Icons.close),
      findsNWidgets(2),
      reason: 'running+queued 行取消',
    );
  });

  testWidgets('点击取消 → 任务终态;全部取消 → 全终态', (tester) async {
    await seedTask(TaskState.running);
    await seedTask(TaskState.queued);

    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 全部取消(异步链经 pump 推进)
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final tasks = await repo.all();
      if (tasks.isNotEmpty && tasks.every((t) => t.state.isFinal)) break;
    }
    final tasks = await repo.all();
    expect(
      tasks.every((t) => t.state.isFinal),
      isTrue,
      reason: 'running 令牌 + queued 直接终态,全部落终态',
    );
    expect(find.text('暂无进行中的任务'), findsOneWidget);
  });

  testWidgets('failed 行重试按钮 → 任务重新入队执行', (tester) async {
    await seedTask(TaskState.failed);
    await tester.pumpWidget(wrap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tasks = await repo.all();
    expect(tasks.single.state, isNot(TaskState.failed), reason: '重试后离开失败态');
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

/// 静态调度器:start() 空操作,任务不执行(渲染测试展示 seed 状态)。
class _StaticTaskManager extends TaskManager {
  _StaticTaskManager({
    required this.repo,
    required super.taskRepository,
    required super.historyRepository,
    required super.ffmpegService,
    required super.platformAdapter,
    required super.logger,
    super.retryDelay,
  });

  final TaskRepository repo;

  @override
  Future<void> start() async {}

  /// 仓储级取消(静态调度器不维护内存队列,seed 任务直接落终态)。
  @override
  Future<void> cancelAll() async {
    for (final t in await repo.all()) {
      if (!t.state.isFinal) {
        await repo.update(t.copyWith(state: TaskState.cancelled));
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/features/export/application/export_controller.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/export/application/export_state.dart';
import 'package:chameleon_gif/features/export/presentation/export_complete_dialog.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';

/// [ExportCompleteDialog] 渲染与按钮测试(纯 UI,动作仅验证转发)。
void main() {
  final task = ExportTask(
    id: 1,
    videoPath: '/tmp/videos/demo.mp4',
    outputPath: '/tmp/gifforge_1/out.gif',
    settings: const GifSetting(),
    state: TaskState.completed,
    createdAt: DateTime(2026, 1, 1, 10),
    startedAt: DateTime(2026, 1, 1, 10, 0, 1),
    finishedAt: DateTime(2026, 1, 1, 10, 0, 5),
  );

  Future<void> pump(
    WidgetTester tester, {
    _SpyExportController? controller,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (controller != null)
            exportControllerProvider.overrideWith(() => controller),
          // 真实 controller 的 build 依赖任务链,注入 Noop 服务满足装配
          appLoggerProvider.overrideWithValue(AppLogger()),
          ffmpegServiceProvider.overrideWithValue(_NoopFfmpegService()),
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          historyRepositoryProvider.overrideWithValue(
            InMemoryHistoryRepository(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ExportCompleteDialog(task: task, outputSizeBytes: 1536),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('展示文件/大小/耗时', (tester) async {
    await pump(tester);

    expect(find.text('导出完成'), findsOneWidget);
    expect(find.textContaining('/tmp/gifforge_1/out.gif'), findsOneWidget);
    expect(find.text('大小:1.5 KB'), findsOneWidget);
    expect(find.text('耗时:4 秒'), findsOneWidget);
    expect(find.text('打开文件夹'), findsOneWidget);
    expect(find.text('再转一次'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('关闭按钮收起弹窗', (tester) async {
    await pump(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
  });

  testWidgets('再转一次收起弹窗并复位', (tester) async {
    final spy = _SpyExportController();
    await pump(tester, controller: spy);

    await tester.tap(find.text('再转一次'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
    expect(spy.resetCount, 1, reason: '再转一次应复位会话');
  });

  testWidgets('打开文件夹转发到控制器用例', (tester) async {
    final spy = _SpyExportController();
    await pump(tester, controller: spy);

    await tester.tap(find.text('打开文件夹'));
    await tester.pump();

    expect(spy.openFolderCalls, 1);
  });
}

/// 动作转发 spy(验证 UI 只转发、不直调基础设施)。
class _SpyExportController extends ExportController {
  int openFolderCalls = 0;
  int resetCount = 0;

  /// 覆盖 build:spy 不接真实依赖链(taskManager/ffmpegService)。
  @override
  ExportFormState build() => const ExportFormState.idle();

  @override
  Future<void> openOutputFolder() async {
    openFolderCalls++;
  }

  @override
  void reset() {
    resetCount++;
    super.reset();
  }
}

/// 无操作 FFmpeg 服务(本测试不触导出,仅满足 controller 装配)。
class _NoopFfmpegService implements FFmpegService {
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

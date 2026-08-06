import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/encode_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/export/presentation/export_complete_dialog.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 组合壳链路测试(app/presentation/preview_screen):
/// 导入 → 预览 → 导出(成功弹窗 / 失败 SnackBar)。
void main() {
  late SharedPreferences prefs;
  late _FlowFakeService service;
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_flow_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  (Widget, _FlowFakeService) buildApp() {
    service = _FlowFakeService();
    return (
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          appLoggerProvider.overrideWithValue(AppLogger()),
          filePickPortProvider.overrideWithValue(_FakeFilePickPort()),
          parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
          previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
          platformAdapterProvider.overrideWithValue(
            _FlowAdapter(tempRoot.path),
          ),
          taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
          historyRepositoryProvider.overrideWithValue(
            InMemoryHistoryRepository(),
          ),
          taskManagerProvider.overrideWith(
            (ref) => TaskManager(
              taskRepository: ref.read(taskRepositoryProvider),
              historyRepository: ref.read(historyRepositoryProvider),
              ffmpegService: service,
              platformAdapter: _FlowAdapter(tempRoot.path),
              logger: AppLogger(),
              retryDelay: (_) async {},
            ),
          ),
        ],
        child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
      ),
      service,
    );
  }

  testWidgets('导出成功 → 完成弹窗(含文件路径与大小)', (tester) async {
    // 桌面尺寸:触发双栏布局,导出按钮在右栏可见
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (app, svc) = buildApp();
    svc.result = const _FlowResult.success();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    // TaskManager 含真实 IO(建目录/写文件),fake async 下挂起:
    // 点击与等待整体放入 runAsync,让完整异步链在真实事件循环完成
    await tester.runAsync(() async {
      await tester.tap(find.text('导出 GIF'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsOneWidget);
    expect(find.textContaining('out.gif'), findsOneWidget);
    expect(find.text('大小:123 B'), findsOneWidget);
  });

  testWidgets('回归:开始时间输入不回车,导出仍生效(flush 兜底)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (app, svc) = buildApp();
    svc.result = const _FlowResult.success();
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    // 开始时间框 = 第 2 个 TextField(循环/开始/结束),输入不回车
    // (旧 bug:不按回车直接导出,裁剪不生效)
    await tester.enterText(find.byType(TextField).at(1), '00:02.000');
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('导出 GIF'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(
      svc.lastSetting!.start,
      const Duration(seconds: 2),
      reason: '未回车输入也必须生效',
    );
  });

  testWidgets('导出失败 → SnackBar 展示用户文案,无弹窗', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (app, svc) = buildApp();
    svc.result = const _FlowResult.failure(
      EncodeException(errorCode: 'GIF_1_ENCODE'),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('导出 GIF'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
    expect(find.text('转换失败,请重试或调整参数'), findsOneWidget);
  });
}

// ---- 测试替身 ----

class _FakeFilePickPort implements FilePickPort {
  @override
  Future<List<String>?> pickImages() async => null;
  @override
  Future<String?> pickMp4() async => '/tmp/videos/demo.mp4';

  @override
  Future<List<String>?> pickMp4s() async => null;
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 5),
    width: 640,
    height: 360,
    fps: 30.0,
    codec: 'h264',
  );
}

class _FlowAdapter extends PlatformAdapter {
  _FlowAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;

  @override
  Future<void> openFolder(String path) async {}
}

sealed class _FlowResult {
  const _FlowResult();

  const factory _FlowResult.success() = _FlowSuccess;
  const factory _FlowResult.failure(Object error) = _FlowFailure;
}

class _FlowSuccess extends _FlowResult {
  const _FlowSuccess();
}

class _FlowFailure extends _FlowResult {
  const _FlowFailure(this.error);

  final Object error;
}

class _FlowFakeService implements FFmpegService {
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

  _FlowResult result = const _FlowResult.success();
  GifSetting? lastSetting;

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
    lastSetting = setting;
    onProgress?.call(
      TaskProgress(taskId: taskId, percent: 1.0, elapsed: Duration.zero),
    );
    switch (result) {
      case _FlowSuccess():
        await File(outputPath).writeAsBytes(List.filled(123, 1));
        return const ConvertResult(
          exitCode: 0,
          elapsed: Duration(seconds: 1),
          outputSizeBytes: 123,
        );
      case _FlowFailure(:final error):
        throw error;
    }
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/converter/application/command_builder.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/timeline/application/timeline_providers.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';

/// 组合壳工作台链路测试(P4-WP3):参数表单 → 时间轴联动 → 导出命令快照。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_ws_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(_FakeFilePickPort()),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(_WsAdapter(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: _WsFakeService(),
            platformAdapter: _WsAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
    );
  }

  /// 进入工作台(导入 → 预览页),桌面尺寸双栏布局。
  Future<ProviderContainer> gotoWorkspace(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ChameleonGifApp)),
    );
  }

  testWidgets('参数表单 → 时间轴联动 → 导出命令快照验收', (tester) async {
    final container = await gotoWorkspace(tester);

    // ① 表单:帧率 24、宽度 640、起止 3s/9s(经时间输入框)
    await tester.tap(find.text('15.0 fps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24.0 fps').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('480 px'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('640 px').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '00:03.000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(2), '00:09.000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final form = container.read(exportControllerProvider);
    expect(form.fps, 24.0);
    expect(form.width, 640);
    expect(form.start, const Duration(seconds: 3));
    expect(form.end, const Duration(seconds: 9));

    // ② 时间轴联动:表单提交已同步时间轴选区
    expect(
      container.read(timelineControllerProvider).start,
      const Duration(seconds: 3),
    );
    expect(
      container.read(timelineControllerProvider).end,
      const Duration(seconds: 9),
    );

    // ③ 导出 → 命令快照验收:TaskManager 收到的 settings + CommandBuilder args
    await tester.runAsync(() async {
      await tester.tap(find.text('导出 GIF'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final taskRepo = container.read(taskRepositoryProvider);
    final tasks = await taskRepo.all();
    expect(tasks, hasLength(1));
    final settings = tasks.single.settings;
    expect(settings.fps, 24.0);
    expect(settings.width, 640);
    expect(settings.start, const Duration(seconds: 3));
    expect(settings.end, const Duration(seconds: 9));

    const video = VideoInfo(
      path: '/tmp/videos/demo.mp4',
      formatName: 'mp4',
      duration: Duration(seconds: 10),
      width: 640,
      height: 360,
      fps: 30.0,
      codec: 'h264',
    );
    final commands = const GifCommandBuilder().build(
      setting: settings,
      video: video,
      inputPath: video.path,
      workDir: '/tmp/work',
      outputPath: '/tmp/work/out.gif',
    );
    // 第一遍 palette:滤镜串含 fps=24 / scale=640
    final palette = commands.first.args;
    expect(
      palette,
      containsAll([
        '-vf',
        'fps=24,scale=640:-1:flags=lanczos,palettegen=max_colors=256',
      ]),
    );
    // 第二遍 encode:裁剪参数 -ss/-to + paletteuse
    final encode = commands.last.args;
    expect(encode, containsAll(['-ss', '00:00:03.000']));
    expect(encode, containsAll(['-to', '00:00:09.000']));
    expect(
      encode,
      containsAll([
        '-lavfi',
        'fps=24,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5',
      ]),
    );
  });
}

// ---- 测试替身 ----

class _FakeFilePickPort implements FilePickPort {
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
    duration: const Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30.0,
    codec: 'h264',
  );
}

class _WsAdapter extends PlatformAdapter {
  _WsAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;

  @override
  Future<void> openFolder(String path) async {}
}

class _WsFakeService implements FFmpegService {
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
}

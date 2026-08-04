import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/domain_exception.dart';
import 'package:gif_forge/domain/exceptions/palette_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_progress.dart';
import 'package:gif_forge/features/converter/application/ffmpeg_service_engine.dart';

/// [FfmpegServiceEngine] 编排测试(注入 [FakeEngine],纯 Dart)。
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

  late Directory workDir;
  late String outputPath;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('gifforge_test_');
    outputPath = '${workDir.path}/out.gif';
  });

  tearDown(() async {
    await workDir.delete(recursive: true);
  });

  FfmpegServiceEngine build(FakeEngine engine) =>
      FfmpegServiceEngine(engine: engine);

  test('成功:调色板两遍顺序执行,elapsed 累加,outputSizeBytes 读输出文件', () async {
    final engine = FakeEngine(exitCode: 0);
    await File(outputPath).writeAsString('GIF89a-fake');

    final result = await build(engine).convert(
      setting: const GifSetting(),
      video: video,
      taskId: 1,
      workDir: workDir.path,
      outputPath: outputPath,
    );

    expect(engine.commands, hasLength(2));
    expect(engine.commands[0].first, '-ss');
    expect(
      engine.commands[0].contains('-progress'),
      isFalse,
      reason: '调色板第一遍无进度',
    );
    expect(engine.commands[1], containsAll(['-progress', 'pipe:1']));
    expect(result.exitCode, 0);
    expect(result.elapsed, const Duration(seconds: 2)); // 两条命令各 1s
    expect(result.outputSizeBytes, 'GIF89a-fake'.length);
  });

  test(
    '进度:out_time_us 行经 ProgressParser → onProgress 回调 TaskProgress',
    () async {
      final engine = FakeEngine(
        exitCode: 0,
        stdoutLines: ['out_time_us=5000000'],
      );
      final progresses = <TaskProgress>[];

      await build(engine).convert(
        setting: const GifSetting(),
        video: video,
        taskId: 7,
        workDir: workDir.path,
        outputPath: outputPath,
        onProgress: progresses.add,
      );

      // 10s 视频,5s 处 = 50%
      expect(progresses, isNotEmpty);
      expect(progresses.last.percent, closeTo(0.5, 0.001));
      expect(progresses.last.taskId, 7);
    },
  );

  test('非 0 退出 + 特征 stderr → 领域异常', () async {
    final engine = FakeEngine(
      exitCode: 1,
      stderrLines: ['No space left on device'],
    );

    expect(
      () => build(engine).convert(
        setting: const GifSetting(),
        video: video,
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      ),
      throwsA(
        isA<DomainException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_1_DISK_FULL',
        ),
      ),
    );
  });

  test('调色板第一遍失败 → PaletteException(第二遍不再执行)', () async {
    final engine = FakeEngine(
      exitCode: 1,
      stderrLines: ['palettegen: Error initializing output stream'],
    );

    expect(
      () => build(engine).convert(
        setting: const GifSetting(),
        video: video,
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      ),
      throwsA(isA<PaletteException>()),
    );
    expect(engine.commands, hasLength(1), reason: '第一遍失败即停止');
  });

  test('取消:token 已置 → 不再执行后续命令,返回 cancelled 结果', () async {
    final engine = FakeEngine(exitCode: 0, cancelOnRun: true);
    final token = CancelToken();

    final result = await build(engine).convert(
      setting: const GifSetting(),
      video: video,
      taskId: 1,
      workDir: workDir.path,
      outputPath: outputPath,
      cancelToken: token,
    );

    expect(token.isCancelled, isTrue);
    expect(result.cancelled, isTrue);
    expect(engine.commands, hasLength(1), reason: '取消后短路');
  });

  test('标准单遍(usePalette=false 由 Service 默认走调色板,命令数=2)', () async {
    // Service 恒走默认调色板两遍(质量最佳,§6.1);单遍切换是后续版本能力
    final engine = FakeEngine(exitCode: 0);
    await build(engine).convert(
      setting: const GifSetting(),
      video: video,
      taskId: 1,
      workDir: workDir.path,
      outputPath: outputPath,
    );
    expect(engine.commands, hasLength(2));
    expect(engine.commands.first.first, '-ss');
    expect(
      engine.commands.first,
      containsAll([
        '-vf',
        'fps=15,scale=480:-1:flags=lanczos,palettegen=max_colors=256',
      ]),
    );
  });
}

class FakeEngine implements FFmpegEngine {
  FakeEngine({
    this.exitCode = 0,
    this.stdoutLines = const [],
    this.stderrLines = const [],
    this.cancelOnRun = false,
  });

  final int exitCode;
  final List<String> stdoutLines;
  final List<String> stderrLines;
  final bool cancelOnRun;

  final List<List<String>> commands = [];

  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    commands.add(request.command);
    if (cancelOnRun) cancelToken?.cancel();
    for (final line in stdoutLines) {
      onProgress?.call(line);
    }
    for (final line in stderrLines) {
      onLog?.call(line);
    }
    return ConvertResult(
      exitCode: exitCode,
      elapsed: const Duration(seconds: 1),
      cancelled: cancelToken?.isCancelled ?? false,
    );
  }
}

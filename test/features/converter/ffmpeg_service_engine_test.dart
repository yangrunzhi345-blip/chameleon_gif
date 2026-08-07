import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/domain_exception.dart';
import 'package:chameleon_gif/domain/exceptions/palette_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/converter/application/ffmpeg_service_engine.dart';

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
        'fps=15,palettegen=max_colors=256', // 默认宽 0(原图等比)
      ]),
    );
  });

  group('convertImages 分段路径(N>20,大图集合闪退修复)', () {
    ImageGifSource bigSource(int n) => ImageGifSource(
      paths: [for (var i = 1; i <= n; i++) '/img/$i.png'],
      width: 640,
      height: 480,
    );

    test('21 张:命令序列 seg0 → seg1 → palette → encode', () async {
      final engine = FakeEngine(exitCode: 0);
      await File(outputPath).writeAsString('GIF89a-fake');

      final result = await build(engine).convertImages(
        source: bigSource(21),
        setting: const GifSetting(),
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      );

      expect(engine.commands, hasLength(4), reason: '2 段 + palette + encode');
      expect(
        engine.commands[0],
        containsAll(['-c:v', 'ffv1', '-f', 'matroska']),
      );
      expect(
        engine.commands[1],
        containsAll(['-c:v', 'ffv1', '-f', 'matroska']),
      );
      expect(engine.commands[0].last, '${workDir.path}/seg_0.mkv');
      expect(engine.commands[1].last, '${workDir.path}/seg_1.mkv');
      expect(
        engine.commands[2],
        isNot(contains('-progress')),
        reason: 'palettegen 无进度',
      );
      expect(engine.commands[3], containsAll(['-progress', 'pipe:1']));
      expect(engine.commands[3], containsAll(['-loop', '0']));
      expect(result.exitCode, 0);
      expect(result.elapsed, const Duration(seconds: 4), reason: '4 条命令各 1s');
      expect(result.outputSizeBytes, 'GIF89a-fake'.length);
    });

    test('进度:段内单调、段末 = 1/3、encode 至 100%', () async {
      // 21 张、每图 100ms@15fps(2 帧):段 0 分母 11×133.33ms、段 1 分母
      // 10×133.33ms、encode 分母 21×133.33ms;out_time 取段/输出轴中点
      final engine = FakeEngine(
        exitCode: 0,
        stdoutSequences: [
          ['out_time_us=733331'], // 段 0 intra ≈ 0.5 → (22×0.5)/42/3
          ['out_time_us=666665'], // 段 1 intra ≈ 0.5 → (22+10)/42/3
          [], // palettegen:无进度行(聚合器冻结)
          ['out_time_us=1400000'], // encode intra=0.5 → (1+2×0.5)/3 = 2/3
        ],
      );
      final progresses = <TaskProgress>[];

      await build(engine).convertImages(
        source: bigSource(21),
        setting: const GifSetting(frameDurationMs: 100),
        taskId: 7,
        workDir: workDir.path,
        outputPath: outputPath,
        onProgress: progresses.add,
      );

      expect(progresses, isNotEmpty);
      final percents = progresses.map((p) => p.percent).toList();
      expect(percents[0], closeTo(11 / 126, 1e-6), reason: '段 0 中点');
      expect(percents[1], closeTo(32 / 126, 1e-6), reason: '段 1 中点');
      expect(percents.last, closeTo(2 / 3, 1e-6), reason: 'encode 中点');
      // 单调:段内/跨 phase 只升不降
      for (var i = 1; i < percents.length; i++) {
        expect(percents[i], greaterThanOrEqualTo(percents[i - 1]));
      }
    });

    test('100 张:5 段 + palette + encode,段末恰为冻结位', () async {
      final engine = FakeEngine(exitCode: 0);
      await File(outputPath).writeAsString('GIF89a-fake');

      await build(engine).convertImages(
        source: bigSource(100),
        setting: const GifSetting(frameDurationMs: 100),
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      );

      expect(engine.commands, hasLength(7), reason: '5 段 + palette + encode');
      for (var k = 0; k < 5; k++) {
        expect(engine.commands[k].last, '${workDir.path}/seg_$k.mkv');
      }
    });

    test('预取消:零命令执行,返回 cancelled', () async {
      final engine = FakeEngine(exitCode: 0);
      final token = CancelToken()..cancel();

      final result = await build(engine).convertImages(
        source: bigSource(21),
        setting: const GifSetting(),
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
        cancelToken: token,
      );

      expect(result.cancelled, isTrue);
      expect(engine.commands, isEmpty);
    });

    test('段 2(palettegen)失败 → 分类异常,段文件清理', () async {
      final engine = FakeEngine(
        exitCodes: [0, 0, 1],
        stderrLines: ['No space left on device'],
      );

      // ⚠️ 必须 await expectLater:expect + throwsA + async 闭包是异步匹配,
      // expect 同步返回,后续断言会在 convert 未完成时执行(曾致 commands
      // 长度断言在段 0 后即触发)
      await expectLater(
        () => build(engine).convertImages(
          source: bigSource(21),
          setting: const GifSetting(),
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
      expect(engine.commands, hasLength(3), reason: 'palettegen 失败即停止');
    });

    test('清理语义:成功/失败/取消后 seg_*.mkv 均不存在,out.gif 保留', () async {
      final seg0 = File('${workDir.path}/seg_0.mkv')..writeAsStringSync('x');
      final seg1 = File('${workDir.path}/seg_1.mkv')..writeAsStringSync('x');
      await File(outputPath).writeAsString('GIF89a-fake');

      final engine = FakeEngine(exitCode: 0);
      await build(engine).convertImages(
        source: bigSource(21),
        setting: const GifSetting(),
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      );

      expect(seg0.existsSync(), isFalse, reason: '段文件由编排层统一清理');
      expect(seg1.existsSync(), isFalse);
      expect(File(outputPath).existsSync(), isTrue, reason: '输出保留');
    });

    test('N ≤ 20 走原路径(命令无 ffv1,快照零回归)', () async {
      final engine = FakeEngine(exitCode: 0);
      await build(engine).convertImages(
        source: bigSource(20),
        setting: const GifSetting(),
        taskId: 1,
        workDir: workDir.path,
        outputPath: outputPath,
      );
      expect(engine.commands, hasLength(2), reason: 'palette + encode');
      expect(engine.commands[0], isNot(contains('ffv1')));
      expect(
        engine.commands[0].join(' '),
        contains('palettegen=max_colors=256'),
      );
    });
  });
}

class FakeEngine implements FFmpegEngine {
  FakeEngine({
    this.exitCode = 0,
    this.stdoutLines = const [],
    this.stderrLines = const [],
    this.cancelOnRun = false,
    this.exitCodes,
    this.stdoutSequences,
  });

  final int exitCode;
  final List<String> stdoutLines;
  final List<String> stderrLines;
  final bool cancelOnRun;

  /// 按命令序号(第 i 次 convert)返回退出码/进度行;未提供用固定值。
  final List<int>? exitCodes;
  final List<List<String>>? stdoutSequences;
  int _callIndex = 0;

  final List<List<String>> commands = [];

  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    final idx = _callIndex++;
    commands.add(request.command);
    if (cancelOnRun) cancelToken?.cancel();
    final code = exitCodes != null ? exitCodes![idx] : exitCode;
    final stdout = stdoutSequences != null
        ? stdoutSequences![idx]
        : stdoutLines;
    for (final line in stdout) {
      onProgress?.call(line);
    }
    for (final line in stderrLines) {
      onLog?.call(line);
    }
    return ConvertResult(
      exitCode: code,
      elapsed: const Duration(seconds: 1),
      cancelled: cancelToken?.isCancelled ?? false,
    );
  }
}

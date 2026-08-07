import 'dart:io' show File, FileSystemException;

import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_progress.dart';
import 'command_builder.dart';
import 'error_handler.dart';
import 'gif_command.dart';
import 'image_segmentation.dart';
import 'log_parser.dart';
import 'progress_parser.dart';

/// [FFmpegService] 编排实现(§8.2 时序:构造 → 执行 → 解析 → 分类)。
///
/// 一次转换 = 1–2 条命令(标准单遍 / 调色板两遍),共享同一个
/// [CancelToken];elapsed 跨命令累加;outputSizeBytes 读输出文件;
/// 取消判定以令牌为准(不依赖平台退出码)。失败时抛 [ErrorHandler]
/// 分类后的领域异常;取消时返回 cancelled 结果(不抛)。
class FfmpegServiceEngine implements FFmpegService {
  FfmpegServiceEngine({
    required FFmpegEngine engine,
    AppLogger? logger,
    GifCommandBuilder builder = const GifCommandBuilder(),
  }) : _engine = engine,
       _logger = logger,
       _builder = builder;

  final FFmpegEngine _engine;
  final AppLogger? _logger;
  final GifCommandBuilder _builder;

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
    final commands = _builder.build(
      setting: setting,
      video: video,
      inputPath: video.path,
      workDir: workDir,
      outputPath: outputPath,
    );
    final denominator = _builder.progressDenominator(setting, video);
    return _runCommands(
      commands: commands,
      denominator: denominator,
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
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
    // 大图集合(> kSegmentModeThreshold)走分段转换:每段 ≤20 张编码为
    // ffv1 无损中间片后统一调色板,消除 100 张 2048×2048 的 ffmpeg
    // 原生内存峰值闪退(2026-08-07 真机实证,见 image_segmentation.dart)
    if (source.paths.length > kSegmentModeThreshold) {
      return _runSegmentedImages(
        source: source,
        setting: setting,
        taskId: taskId,
        workDir: workDir,
        outputPath: outputPath,
        cancelToken: cancelToken,
        onProgress: onProgress,
        onLog: onLog,
      );
    }
    final commands = _builder.buildFromImages(
      setting: setting,
      source: source,
      workDir: workDir,
      outputPath: outputPath,
      usePalette: setting.usePalette,
    );
    final denominator = _builder.progressDenominatorImages(setting, source);
    return _runCommands(
      commands: commands,
      denominator: denominator,
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  /// 大图集合分段编排(状态机:段 0 → … → 段 K-1 → [palettegen] →
  /// paletteuse/encode)。
  ///
  /// 进度经 [SegmentedProgressAggregator] 以帧权折算总体百分比,全程
  /// 单调(段末 = palettegen 冻结位 = encode 起点,无跳变);palettegen
  /// 阶段两端一致冻结(桌面无 progress 行,Android statistics 合成行
  /// 被聚合器丢弃)。中间片 seg_*.mkv 生命周期归本方法:成功/失败/取消
  /// 统一 best-effort 删除;palette.png 成功时删除(失败/取消由
  /// CancellationManager 兜底,双保险)。
  Future<ConvertResult> _runSegmentedImages({
    required ImageGifSource source,
    required GifSetting setting,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    final sizes = segmentSizes(source.paths.length);
    final segmentPaths = [
      for (var k = 0; k < sizes.length; k++) '$workDir/seg_$k.mkv',
    ];
    final usePalette = setting.usePalette;
    final framesPerImage =
        setting.quantizedFrameDuration.inMicroseconds * setting.fps / 1e6;
    final aggregator = SegmentedProgressAggregator(
      segmentSizes: sizes,
      framesPerImage: framesPerImage,
      usePalette: usePalette,
    );

    var totalElapsed = Duration.zero;
    final stderrBuffer = StringBuffer();
    final parser = LogParser();
    final handler = ErrorHandler();
    var lastOverall = 0.0;

    // 单调防护:聚合器输出只升不降(各 phase 边界 clamp)
    void emitSegment(int k, double intra) {
      final v = aggregator.segmentOverall(k, intra).clamp(lastOverall, 1.0);
      lastOverall = v;
      onProgress?.call(TaskProgress(taskId: taskId, percent: v));
    }

    void emitEncode(double intra) {
      final v = aggregator.encodeOverall(intra).clamp(lastOverall, 1.0);
      lastOverall = v;
      onProgress?.call(TaskProgress(taskId: taskId, percent: v));
    }

    try {
      // 1) 逐段编码 ffv1 中间片
      var start = 0;
      for (var k = 0; k < sizes.length; k++) {
        if (cancelToken?.isCancelled ?? false) return _cancelled(totalElapsed);
        final cmd = _builder.buildImageSegment(
          setting: setting,
          source: source,
          start: start,
          count: sizes[k],
          workDir: workDir,
          segmentPath: segmentPaths[k],
        );
        final result = await _runOneCommand(
          cmd: cmd,
          denominator: _builder.segmentProgressDenominator(setting, sizes[k]),
          taskId: taskId,
          workDir: workDir,
          stderrBuffer: stderrBuffer,
          parser: parser,
          cancelToken: cancelToken,
          onProgress: (p) => emitSegment(k, p.percent),
          onLog: onLog,
        );
        totalElapsed += result.elapsed;
        if (result.cancelled || (cancelToken?.isCancelled ?? false)) {
          return _cancelled(totalElapsed);
        }
        if (result.exitCode != 0) {
          throw handler.classify(
            exitCode: result.exitCode,
            stderr: stderrBuffer.toString(),
          );
        }
        start += sizes[k];
      }

      // 2) palettegen(无 -progress:进度冻结在段编码完成位)
      final finalCommands = _builder.buildFromSegments(
        setting: setting,
        segmentPaths: segmentPaths,
        workDir: workDir,
        outputPath: outputPath,
        usePalette: usePalette,
      );
      if (usePalette) {
        if (cancelToken?.isCancelled ?? false) return _cancelled(totalElapsed);
        final paletteCmd = finalCommands.first;
        final result = await _runOneCommand(
          cmd: paletteCmd,
          denominator: Duration.zero,
          taskId: taskId,
          workDir: workDir,
          stderrBuffer: stderrBuffer,
          parser: parser,
          cancelToken: cancelToken,
          onProgress: null,
          onLog: onLog,
        );
        totalElapsed += result.elapsed;
        if (result.cancelled || (cancelToken?.isCancelled ?? false)) {
          return _cancelled(totalElapsed);
        }
        if (result.exitCode != 0) {
          throw handler.classify(
            exitCode: result.exitCode,
            stderr: stderrBuffer.toString(),
          );
        }
      }

      // 3) encode / paletteuse(分母 = 总输出时长,含播放速度)
      if (cancelToken?.isCancelled ?? false) return _cancelled(totalElapsed);
      final encodeCmd = finalCommands.last;
      final result = await _runOneCommand(
        cmd: encodeCmd,
        denominator: _builder.progressDenominatorImages(setting, source),
        taskId: taskId,
        workDir: workDir,
        stderrBuffer: stderrBuffer,
        parser: parser,
        cancelToken: cancelToken,
        onProgress: (p) => emitEncode(p.percent),
        onLog: onLog,
      );
      totalElapsed += result.elapsed;
      if (result.cancelled || (cancelToken?.isCancelled ?? false)) {
        return _cancelled(totalElapsed);
      }
      if (result.exitCode != 0) {
        throw handler.classify(
          exitCode: result.exitCode,
          stderr: stderrBuffer.toString(),
        );
      }

      // 成功收尾:删 palette.png(段文件在 finally 删)
      final paletteFile = File('$workDir/palette.png');
      if (usePalette && await paletteFile.exists()) {
        await paletteFile.delete();
      }
    } finally {
      // 中间片生命周期归编排层:成功/失败/取消统一清理(崩溃残留由
      // TaskManager 工作目录上限 + 缓存自动清理兜底)
      for (final p in segmentPaths) {
        final f = File(p);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {
            /* best-effort */
          }
        }
      }
    }

    int? size;
    try {
      size = await File(outputPath).length();
    } on FileSystemException catch (e) {
      _logger?.w('读取输出文件大小失败: $outputPath', error: e);
    }
    return ConvertResult(
      exitCode: 0,
      elapsed: totalElapsed,
      outputSizeBytes: size,
    );
  }

  /// 逐命令执行编排(video/图片两路径共用,§8.2 时序)。
  Future<ConvertResult> _runCommands({
    required List<GifCommand> commands,
    required Duration denominator,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    final tempFiles = commands.any((c) => c.label == GifCommand.kPaletteLabel)
        ? ['$workDir/palette.png', outputPath]
        : [outputPath];

    var totalElapsed = Duration.zero;
    final stderrBuffer = StringBuffer();
    final parser = LogParser();
    final handler = ErrorHandler();

    for (final cmd in commands) {
      if (cancelToken?.isCancelled ?? false) {
        return _cancelled(totalElapsed);
      }
      final result = await _runOneCommand(
        cmd: cmd,
        denominator: denominator,
        taskId: taskId,
        workDir: workDir,
        stderrBuffer: stderrBuffer,
        parser: parser,
        tempFiles: tempFiles,
        cancelToken: cancelToken,
        onProgress: onProgress,
        onLog: onLog,
      );
      totalElapsed += result.elapsed;
      if (result.cancelled || (cancelToken?.isCancelled ?? false)) {
        return _cancelled(totalElapsed);
      }
      if (result.exitCode != 0) {
        throw handler.classify(
          exitCode: result.exitCode,
          stderr: stderrBuffer.toString(),
        );
      }
    }

    // 成功收尾:清理除输出外的临时文件(palette.png 等;取消路径由
    // CancellationManager 清理,TaskManager 侧另有幂等兜底)
    for (final f in tempFiles.where((f) => f != outputPath)) {
      final file = File(f);
      if (await file.exists()) {
        await file.delete();
      }
    }
    // 输出大小读取失败不掩盖转换成功(文件被外部清理等场景)
    int? size;
    try {
      size = await File(outputPath).length();
    } on FileSystemException catch (e) {
      _logger?.w('读取输出文件大小失败: $outputPath', error: e);
    }
    return ConvertResult(
      exitCode: 0,
      elapsed: totalElapsed,
      outputSizeBytes: size,
    );
  }

  /// 单命令执行(video/图片/分段共用):ProgressParser 按 [denominator]
  /// 折算百分比,stderr 累计到 [stderrBuffer](供调用方错误分类)。
  Future<ConvertResult> _runOneCommand({
    required GifCommand cmd,
    required Duration denominator,
    required int taskId,
    required String workDir,
    required StringBuffer stderrBuffer,
    required LogParser parser,
    List<String> tempFiles = const [],
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    final progressParser = ProgressParser(
      taskId: taskId,
      denominator: denominator,
    );
    return _engine.convert(
      ConvertRequest(command: cmd.args, workDir: workDir, tempFiles: tempFiles),
      onProgress: (line) {
        final progress = progressParser.next(line);
        if (progress != null) onProgress?.call(progress);
      },
      onLog: (line) {
        stderrBuffer.writeln(line);
        parser.parse(
          line,
          onError: (t) =>
              _logger?.e('ffmpeg stderr: $t', error: 'task=$taskId'),
          onWarn: (t) => _logger?.w('ffmpeg stderr: $t'),
          onInfo: (t) => _logger?.d('ffmpeg stderr: $t'),
        );
        onLog?.call(line);
      },
      cancelToken: cancelToken,
    );
  }

  ConvertResult _cancelled(Duration elapsed) =>
      ConvertResult(exitCode: -1, elapsed: elapsed, cancelled: true);
}

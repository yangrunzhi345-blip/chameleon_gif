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
      final progressParser = ProgressParser(
        taskId: taskId,
        denominator: denominator,
      );
      final result = await _engine.convert(
        ConvertRequest(
          command: cmd.args,
          workDir: workDir,
          tempFiles: tempFiles,
        ),
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

  ConvertResult _cancelled(Duration elapsed) =>
      ConvertResult(exitCode: -1, elapsed: elapsed, cancelled: true);
}

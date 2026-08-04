import 'dart:io' show File, FileSystemException;

import '../../../core/logger/app_logger.dart';
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
    final tempFiles = commands.any((c) => c.label == GifCommand.paletteLabel)
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

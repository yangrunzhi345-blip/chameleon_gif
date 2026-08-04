import 'package:ffmpeg_kit_flutter_minimal/media_information.dart';
import 'package:ffmpeg_kit_flutter_minimal/return_code.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/repository_interfaces/parse_video_port.dart';
import '../../../shared/platform/ffprobe_executor.dart';
import '../../../shared/platform/process_ffprobe_executor.dart';
import '../application/ffprobe_error_classifier.dart';
import '../application/ffprobe_video_info_parser.dart';

/// [ParseVideoPort] 的 ffprobe 实现(P1-WP1,见 docs/12-开发计划.md)。
///
/// 仅负责"调用执行器 → 汇聚结果";决策逻辑全部收敛到纯函数
/// [assemble](成功→[FfprobeVideoInfoParser],失败→[FfprobeErrorClassifier]),
/// 单测经公开构造的 [MediaInformation] 直接覆盖,无平台依赖。
///
/// 执行器经 [PlatformAdapter] 选型:桌面为系统 ffprobe 二进制
/// ([ProcessFfprobeExecutor]),Android 为 ffmpeg_kit 内嵌库。
class FfprobeParseVideoPort implements ParseVideoPort {
  FfprobeParseVideoPort({
    this.executor = const ProcessFfprobeExecutor(),
    this.parser = const FfprobeVideoInfoParser(),
    this.classifier = const FfprobeErrorClassifier(),
    required this.logger,
  });

  final FfprobeExecutor executor;
  final FfprobeVideoInfoParser parser;
  final FfprobeErrorClassifier classifier;
  final AppLogger logger;

  @override
  Future<VideoInfo> parse(String path) async {
    final FfprobeResult result;
    try {
      result = await executor.run(path);
    } on FilePickException {
      rethrow; // FFmpegMissing(GIF_127_PROBE_MISSING)与 UNREACHABLE 原样上抛
    } catch (e, st) {
      logger.e('ffprobe 执行器未预期异常: $path', error: e, stackTrace: st);
      throw FilePickException(
        errorCode: 'GIF_PROBE_UNREACHABLE',
        userMessage: '视频解析服务不可用,请稍后重试',
        cause: e,
      );
    }
    final mediaInfo =
        result.mediaInformation ??
        (result.probeJson == null ? null : MediaInformation(result.probeJson!));
    return assemble(
      isSuccess: result.exitCode == 0,
      exitCode: result.exitCode,
      stderr: result.stderr,
      mediaInfo: mediaInfo,
      path: path,
    );
  }

  /// 汇聚决策(纯函数):取消 → 失败/空信息 → 分类器;成功 → 解析器。
  @visibleForTesting
  VideoInfo assemble({
    required bool isSuccess,
    required int exitCode,
    required String stderr,
    required MediaInformation? mediaInfo,
    required String path,
  }) {
    if (exitCode == ReturnCode.cancel) {
      throw FilePickException(
        errorCode: 'GIF_255_PROBE_CANCELLED',
        userMessage: '视频解析已取消',
      );
    }
    if (!isSuccess || mediaInfo == null) {
      throw classifier.classify(stderr: stderr, exitCode: exitCode);
    }
    return parser.parse(mediaInfo, path: path);
  }
}

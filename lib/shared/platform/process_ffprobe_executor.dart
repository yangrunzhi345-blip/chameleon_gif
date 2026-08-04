import 'dart:convert';
import 'dart:io';

import '../../domain/exceptions/ffmpeg_missing_exception.dart';
import 'ffprobe_executor.dart';

/// 桌面实现:`dart:io Process` 调系统 ffprobe 二进制。
///
/// 参数与 FFprobeKit.getMediaInformation 保持一致,输出形状同构
/// (解析器/夹具零改动)。二进制缺失或不可执行 → [FFmpegMissingException]
/// (独立异常,避免被分类器误判为源文件损坏/缺失)。
class ProcessFfprobeExecutor implements FfprobeExecutor {
  const ProcessFfprobeExecutor({this.binaryName = 'ffprobe'});

  final String binaryName;

  @override
  Future<FfprobeResult> run(String path) async {
    try {
      final result = await Process.run(
        binaryName,
        [
          '-v',
          'error',
          '-hide_banner',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          '-show_chapters',
          '-i',
          path,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final stdout = result.stdout as String;
      return FfprobeResult(
        exitCode: result.exitCode,
        stderr: (result.stderr as String?) ?? '',
        probeJson: (result.exitCode == 0 && stdout.isNotEmpty)
            ? _decodeJson(stdout)
            : null,
      );
    } on ProcessException catch (e) {
      throw FFmpegMissingException(cause: e);
    }
  }

  /// stdout 非 JSON(异常输出)时返回 null,交由调用方按失败处理。
  static Map<dynamic, dynamic>? _decodeJson(String stdout) {
    try {
      return jsonDecode(stdout) as Map<dynamic, dynamic>;
    } on FormatException {
      return null;
    }
  }
}

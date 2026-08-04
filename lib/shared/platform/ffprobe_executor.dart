import 'package:ffmpeg_kit_flutter_minimal/media_information.dart';

/// 一次 ffprobe 执行的平台无关结果。
///
/// [probeJson] 与 [mediaInformation] 至多一个非空,取决于后端:
/// - 桌面(Process 实现):stdout JSON 反序列化 → [probeJson]
/// - Android(FFprobeKit 实现):直接产物 → [mediaInformation]
class FfprobeResult {
  const FfprobeResult({
    required this.exitCode,
    required this.stderr,
    this.probeJson,
    this.mediaInformation,
  });

  final int exitCode;
  final String stderr;
  final Map<dynamic, dynamic>? probeJson;
  final MediaInformation? mediaInformation;
}

/// ffprobe 执行抽象(平台差异收敛点,docs/04-系统架构.md Platform 层)。
///
/// 桌面(Linux/Windows)实现走系统 ffprobe 二进制;Android 实现走
/// ffmpeg_kit_flutter_minimal(该包无桌面平台实现,已实证)。
abstract interface class FfprobeExecutor {
  /// 探测 [path];仅返回原始结果,决策(成功/损坏/缺失分类)由调用方负责。
  Future<FfprobeResult> run(String path);
}

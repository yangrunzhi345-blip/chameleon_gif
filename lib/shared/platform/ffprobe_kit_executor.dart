import 'package:ffmpeg_kit_flutter_minimal/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/media_information_session.dart';
import 'package:meta/meta.dart';

import '../../domain/exceptions/file_pick_exception.dart';
import 'ffprobe_executor.dart';

/// 探测执行函数签名(测试可注入替身;默认指向真实
/// [FFprobeKit.getMediaInformationFromCommandArguments])。
///
/// ⚠️ 必须走**参数数组**版:字符串版 getMediaInformation(path) 内部经
/// `FFmpegKitConfig.parseArguments` 按空格拆分,路径含空格会被拆裂 →
/// ffprobe 报 `No such file or directory`(与 ffmpeg 引擎同根因,
/// 2026-08-07 Android 真机实证);参数数组直传原生侧,路径任意字符安全。
typedef GetMediaInformation =
    Future<MediaInformationSession> Function(
      List<String> arguments, [
      int? waitTimeout,
    ]);

/// Android 实现:ffmpeg_kit_flutter_minimal 内嵌库。
///
/// 行为自 P1 初版原样搬移(含 `GIF_PROBE_UNREACHABLE` 包装);该包无桌面
/// 平台实现(已实证),Android 端本轮不验证,后续随 P8 三平台手工清单确认。
class FfprobeKitFfprobeExecutor implements FfprobeExecutor {
  const FfprobeKitFfprobeExecutor({
    this.getMediaInformation =
        FFprobeKit.getMediaInformationFromCommandArguments,
  });

  /// 探测执行器(注入 seam:单测以 fake session 替身覆盖结果包装逻辑)。
  final GetMediaInformation getMediaInformation;

  /// ffprobe 探测参数(与 [FFprobeKit.getMediaInformation] 内部命令一致;
  /// 参数数组直传,不走空格拆分)。
  @visibleForTesting
  static List<String> probeArguments(String path) => [
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
  ];

  @override
  Future<FfprobeResult> run(String path) async {
    final MediaInformationSession session;
    try {
      session = await getMediaInformation(probeArguments(path));
    } catch (e) {
      throw FilePickException.probeUnreachable(cause: e);
    }
    final code = await session.getReturnCode();
    final mediaInformation = session.getMediaInformation();
    return FfprobeResult(
      exitCode: code?.getValue() ?? -1,
      stderr: await session.getOutput() ?? '',
      mediaInformation: mediaInformation,
      // 关键:getAllProperties() 即 ffprobe JSON 原结构(format/streams),
      // 填入 probeJson 供 FfprobeParseVideoPort 消费(缺失时业务层会兜底
      // 报"错误码 0",曾致 Android 真机视频解析失败)。
      probeJson: mediaInformation?.getAllProperties(),
    );
  }
}

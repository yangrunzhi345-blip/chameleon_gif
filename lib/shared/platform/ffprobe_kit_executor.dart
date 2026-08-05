import 'package:ffmpeg_kit_flutter_minimal/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/media_information_session.dart';

import '../../domain/exceptions/file_pick_exception.dart';
import 'ffprobe_executor.dart';

/// 探测执行函数签名(测试可注入替身;默认指向真实 [FFprobeKit])。
typedef GetMediaInformation =
    Future<MediaInformationSession> Function(String path);

/// Android 实现:ffmpeg_kit_flutter_minimal 内嵌库。
///
/// 行为自 P1 初版原样搬移(含 `GIF_PROBE_UNREACHABLE` 包装);该包无桌面
/// 平台实现(已实证),Android 端本轮不验证,后续随 P8 三平台手工清单确认。
class FfprobeKitFfprobeExecutor implements FfprobeExecutor {
  const FfprobeKitFfprobeExecutor({
    this.getMediaInformation = FFprobeKit.getMediaInformation,
  });

  /// 探测执行器(注入 seam:单测以 fake session 替身覆盖结果包装逻辑)。
  final GetMediaInformation getMediaInformation;

  @override
  Future<FfprobeResult> run(String path) async {
    final MediaInformationSession session;
    try {
      session = await getMediaInformation(path);
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

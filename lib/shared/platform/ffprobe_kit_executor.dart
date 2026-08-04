import 'package:ffmpeg_kit_flutter_minimal/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/media_information_session.dart';

import '../../domain/exceptions/file_pick_exception.dart';
import 'ffprobe_executor.dart';

/// Android 实现:ffmpeg_kit_flutter_minimal 内嵌库。
///
/// 行为自 P1 初版原样搬移(含 `GIF_PROBE_UNREACHABLE` 包装);该包无桌面
/// 平台实现(已实证),Android 端本轮不验证,后续随 P8 三平台手工清单确认。
class FfprobeKitFfprobeExecutor implements FfprobeExecutor {
  const FfprobeKitFfprobeExecutor();

  @override
  Future<FfprobeResult> run(String path) async {
    final MediaInformationSession session;
    try {
      session = await FFprobeKit.getMediaInformation(path);
    } catch (e) {
      throw FilePickException(
        errorCode: 'GIF_PROBE_UNREACHABLE',
        userMessage: '视频解析服务不可用,请稍后重试',
        cause: e,
      );
    }
    final code = await session.getReturnCode();
    return FfprobeResult(
      exitCode: code?.getValue() ?? -1,
      stderr: await session.getOutput() ?? '',
      mediaInformation: session.getMediaInformation(),
    );
  }
}

import 'dart:io' show Directory, Platform;

import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../features/converter/infrastructure/ffmpeg_kit_engine.dart';
import '../../features/converter/infrastructure/process_engine.dart';
import 'ffprobe_executor.dart';
import 'ffprobe_kit_executor.dart';
import 'process_ffprobe_executor.dart';

/// 平台差异收敛点(docs/08-FFmpeg设计.md §8.3.8、docs/04-系统架构.md Platform 层)。
///
/// 业务层禁止写 `Platform.isXxx` 分支,一律经本适配器选型。
class PlatformAdapter {
  const PlatformAdapter();

  /// Android → ffmpeg_kit 内嵌库(首发平台,本轮不验证);
  /// 桌面(Linux/Windows)→ 系统 ffprobe 二进制。
  FfprobeExecutor createFfprobeExecutor() {
    if (Platform.isAndroid) return const FfprobeKitFfprobeExecutor();
    return const ProcessFfprobeExecutor();
  }

  /// 转码引擎选型:Android → ffmpeg_kit 内嵌库;桌面 → 系统 ffmpeg 二进制。
  FFmpegEngine createFfmpegEngine() {
    if (Platform.isAndroid) return FfmpegKitEngine();
    return const ProcessEngine();
  }

  /// 转换工作目录根:桌面用系统临时目录;Android 应用专属目录(P8 确认)。
  String get systemTempDir {
    if (Platform.isAndroid) {
      // TODO(P8): getExternalFilesDir 落地;当前返回系统临时目录占位
      return Directory.systemTemp.path;
    }
    return Directory.systemTemp.path;
  }
}

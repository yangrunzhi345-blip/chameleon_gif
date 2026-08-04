import 'dart:io' show Platform;

import 'ffprobe_executor.dart';
import 'ffprobe_kit_executor.dart';
import 'process_ffprobe_executor.dart';

/// 平台差异收敛点(docs/08-FFmpeg设计.md §8.3.8、docs/04-系统架构.md Platform 层)。
///
/// 业务层禁止写 `Platform.isXxx` 分支,一律经本适配器选型。
/// 本轮只负责 ffprobe 执行器;P3 起扩展 FFmpeg 执行器/进程信号等。
class PlatformAdapter {
  const PlatformAdapter();

  /// Android → ffmpeg_kit 内嵌库(首发平台,本轮不验证);
  /// 桌面(Linux/Windows)→ 系统 ffprobe 二进制。
  FfprobeExecutor createFfprobeExecutor() {
    if (Platform.isAndroid) return const FfprobeKitFfprobeExecutor();
    return const ProcessFfprobeExecutor();
  }
}

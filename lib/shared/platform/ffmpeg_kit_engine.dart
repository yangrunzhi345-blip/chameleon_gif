import 'dart:async';

import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repository_interfaces/ffmpeg_engine.dart';

/// Android FFmpeg 引擎(ffmpeg_kit_flutter_minimal 内嵌库,docs/08 §8.3.8)。
///
/// ⚠️ 接口对齐实现:R-07 已实证该 fork 无 Linux/Windows 平台实现,Android
/// 路径本轮不验证(P8 三平台清单确认)。命令以空格拼接字符串执行
/// (Kit 契约),进度经 statistics 回调(与桌面 -progress pipe:1 行不同,
/// 接入进度留 P8);取消经 `FFmpegKit.cancel(sessionId)`。
class FfmpegKitEngine implements FFmpegEngine {
  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    final completer = Completer<ConvertResult>();
    final sw = Stopwatch()..start();
    final command = assembleCommand(request.command);

    final session = await FFmpegKit.executeAsync(
      command,
      (s) async {
        final returnCode = await s.getReturnCode();
        completer.complete(
          ConvertResult(
            exitCode: returnCode?.getValue() ?? -1,
            elapsed: sw.elapsed,
            cancelled: cancelToken?.isCancelled ?? false,
          ),
        );
      },
      (log) => onLog?.call(log.getMessage()),
      // statistics 回调:Android 进度源(留 P8 接入 ProgressParser 等价物)
      (stat) {},
    );
    final sessionId = session.getSessionId();
    cancelToken?.onCancel(() {
      if (sessionId != null) FFmpegKit.cancel(sessionId);
    });
    return completer.future;
  }

  /// 装配 Kit 契约命令串:ffmpeg 前缀 + 空格拼接(P8 起为纯函数,单测锁定)。
  @visibleForTesting
  static String assembleCommand(List<String> args) =>
      ['ffmpeg', ...args].join(' ');
}

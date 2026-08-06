import 'dart:async';

import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_session_complete_callback.dart';
import 'package:ffmpeg_kit_flutter_minimal/log_callback.dart';
import 'package:ffmpeg_kit_flutter_minimal/statistics_callback.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repository_interfaces/ffmpeg_engine.dart';

/// [FFmpegKit.executeAsync] 签名镜像(位置可选参数;静态 tear-off 为常量,
/// 可作默认值;单测注入 fake 替代不可 mock 的静态 API)。
typedef KitExecuteAsync =
    Future<FFmpegSession> Function(
      String command, [
      FFmpegSessionCompleteCallback? completeCallback,
      LogCallback? logCallback,
      StatisticsCallback? statisticsCallback,
    ]);

/// [FFmpegKit.cancel] 签名镜像。
typedef KitCancel = Future<void> Function([int? sessionId]);

/// Android FFmpeg 引擎(ffmpeg_kit_flutter 内嵌库,docs/08 §8.3.8)。
///
/// ⚠️ 原生载体:R-07 已实证 fork(ffmpeg_kit_flutter_minimal)为纯 Dart 包,
/// 无原生侧;Android 桥与 ffmpeg-kit AAR 由原版 ffmpeg_kit_flutter 6.0.3
/// 提供(同 channel 桥接,见 pubspec 注释)。桌面走系统二进制,本引擎仅
/// Android 实例化。
///
/// 命令以空格拼接字符串执行(Kit 契约);进度经 statistics 回调合成
/// `-progress` 风格文本行喂上层 [ProgressParser](与桌面解析 100% 复用,
/// time 单位微秒与桌面 out_time_us 一致);取消经 `FFmpegKit.cancel(sessionId)`
/// (CancelToken 已取消时 onCancel 立即执行,幂等)。
class FfmpegKitEngine implements FFmpegEngine {
  FfmpegKitEngine({
    this.executeAsync = FFmpegKit.executeAsync,
    this.cancel = FFmpegKit.cancel,
    this.timeout = kKitCommandTimeout,
  });

  final KitExecuteAsync executeAsync;
  final KitCancel cancel;

  /// 命令超时兜底(原生侧回调永不触发时防任务永久 running 占槽;
  /// 桌面 ProcessEngine 已有 exitCode + 3s 强杀双保险,本类仅 Android)。
  static const kKitCommandTimeout = Duration(minutes: 30);

  /// 超时时长(可注入,测试用短值触发)。
  final Duration timeout;

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

    final session = await executeAsync(
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
      (stat) {
        // statistics 合成 -progress 风格行:ProgressParser 按行解析,
        // out_time_us 驱动百分比,total_size/speed 行不产出(对齐桌面)
        onProgress?.call('out_time_us=${stat.getTime().toInt()}');
        onProgress?.call('total_size=${stat.getSize()}');
        onProgress?.call('speed=${stat.getSpeed()}x');
        onProgress?.call('progress=continue');
      },
    );
    final sessionId = session.getSessionId();
    cancelToken?.onCancel(() {
      // CancelToken 已取消时 onCancel 立即执行(覆盖执行中取消窗口)
      if (sessionId != null) cancel(sessionId);
    });
    // 超时兜底:原生回调永不触发(executeAsync 异常/会话丢失)→ 取消会话
    // 并按取消语义返回(上层走 cancelled 终态),避免任务永久 running
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (sessionId != null) unawaited(cancel(sessionId));
        return ConvertResult(
          exitCode: -1,
          elapsed: sw.elapsed,
          cancelled: true,
        );
      },
    );
  }

  /// 装配 Kit 契约命令串:空格拼接(P8 起为纯函数,单测锁定)。
  ///
  /// ⚠️ 不含 `ffmpeg` 可执行名前缀:ffmpeg-kit 的 executeAsync 直接执行
  /// ffmpeg 本体,带前缀时 `ffmpeg` 被当作输出文件名,真机实测报
  /// `Unable to choose an output format for 'ffmpeg'`(桌面 Process 引擎
  /// 需前缀,属引擎差异)。
  ///
  /// 剥离 `-progress <pipe>` 参数对:ffmpeg-kit 重定向 stdout/stderr,不支持
  /// `-progress pipe:1`(真机实测报 `Invalid argument` 致转换失败);进度改由
  /// statistics 回调合成(见 [convert]),桌面 Process 引擎不受影响。
  @visibleForTesting
  static String assembleCommand(List<String> args) {
    final filtered = <String>[];
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '-progress') {
        i++; // 跳过其值(pipe:1),两参数一并剥离
        continue;
      }
      filtered.add(args[i]);
    }
    return filtered.join(' ');
  }
}

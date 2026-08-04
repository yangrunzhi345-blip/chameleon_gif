import 'dart:convert';
import 'dart:io';

import '../../../domain/exceptions/ffmpeg_missing_exception.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';

/// 桌面 FFmpeg 引擎(docs/08 §8.3.8:Linux/Windows 走系统 ffmpeg 二进制)。
///
/// 经 `dart:io Process.start` 直传参数列表(无 shell 拼接,避免引号转义);
/// stdout/stderr 双流**并发**消费(`await for` 双循环 + `Future.wait`,
/// 防管道缓冲填满导致死锁)。二进制缺失 → [FFmpegMissingException]。
///
/// 取消:注册 [CancelToken.onCancel] 回调终止进程;3s 超时强杀与临时文件
/// 清理由 CancellationManager(docs/08 §8.3.6)负责,本引擎只做首次 kill。
class ProcessEngine implements FFmpegEngine {
  const ProcessEngine({this.binaryName = 'ffmpeg'});

  /// 可注入二进制名(测试用不存在的名称验证缺失路径)。
  final String binaryName;

  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    final Process process;
    try {
      process = await Process.start(binaryName, request.command);
    } on ProcessException catch (e) {
      // 二进制不存在/不可执行 → 语义等价 exit 127
      throw FFmpegMissingException(kind: 'ENCODE', cause: e);
    }
    cancelToken?.onCancel(() => process.kill());

    final sw = Stopwatch()..start();
    final stdoutDone = _drain(process.stdout, onProgress);
    final stderrDone = _drain(process.stderr, onLog);
    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);

    return ConvertResult(
      exitCode: exitCode,
      elapsed: sw.elapsed,
      cancelled: cancelToken?.isCancelled ?? false,
    );
  }

  /// 逐行消费流(UTF-8 解码 + 行切分),每行回调一次。
  Future<void> _drain(
    Stream<List<int>> stream,
    void Function(String line)? onLine,
  ) async {
    await for (final line
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      onLine?.call(line);
    }
  }
}

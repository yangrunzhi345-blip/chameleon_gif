import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import 'cancellation_manager.dart';

/// 采集会话结果(结束信号判定依据)。
class CaptureOutcome {
  const CaptureOutcome({
    required this.exitCode,
    required this.stoppedByRequest,
    required this.cancelled,
    required this.elapsed,
  });

  /// 进程退出码(SIGTERM 优雅封口时 ffmpeg 返回 255,不等于失败)。
  final int exitCode;

  /// 是否由手动停止([CaptureSession.stop])触发(保存语义)。
  final bool stoppedByRequest;

  /// 是否由取消([CaptureSession.cancel]/[CancelToken])触发(不保存)。
  final bool cancelled;

  /// 从启动到退出的实际时长。
  final Duration elapsed;
}

/// 一次采集会话(进程生命周期 + stderr 尾部 + 结束信号)。
///
/// 结束信号三态(与 Android 采集语义对齐):
/// - 手动停 [stop]:SIGTERM 优雅封口(ffmpeg 收到 SIGTERM 会写完 moov,
///   产物可用 → 保存);
/// - 超时:命令 `-t` 前置输入限时进程自退(exit 0 → 保存);
/// - 取消 [cancel]:terminateProcess 完整时序 + 幂等删除半成品(不保存)。
class CaptureSession {
  CaptureSession._(
    this._process,
    this._handle,
    this._outputPath,
    this._started,
  );

  final Process _process;
  final ProcessHandle _handle;
  final String _outputPath;
  final DateTime _started;
  bool _stoppedByRequest = false;
  bool _cancelled = false;

  static const _stderrTailLimit = 8;
  final _stderrTail = <String>[];

  /// stdout 原始字节监听(截帧预览:JPEG 帧分割;单订阅者)。
  void Function(Uint8List chunk)? onStdoutBytes;

  /// stderr 尾部(错误映射依据;失败后读取,保持非敏感截断)。
  List<String> get stderrTail => List.unmodifiable(_stderrTail);

  /// 收集 stderr 行(限尾部,防日志膨胀)。
  void addStderrLine(String line) {
    _stderrTail.add(line);
    if (_stderrTail.length > _stderrTailLimit) _stderrTail.removeAt(0);
  }

  /// 手动停止(保存):SIGTERM → 等待退出 → 超时强杀(幂等)。
  Future<void> stop() async {
    _stoppedByRequest = true;
    await terminateProcess(_handle);
  }

  /// 取消(不保存):终止进程 + 幂等删除半成品(重复调用无副作用)。
  Future<void> cancel() async {
    _cancelled = true;
    await terminateProcess(_handle);
    final tmp = File(_outputPath);
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } on FileSystemException {
        // 忽略:清理尽力语义(与 CancellationManager 一致)
      }
    }
  }

  /// 等待进程结束并返回结果(进程被 [stop]/[cancel] 终止后同样返回)。
  Future<CaptureOutcome> waitExit() async {
    final code = await _process.exitCode;
    return CaptureOutcome(
      exitCode: code,
      stoppedByRequest: _stoppedByRequest,
      cancelled: _cancelled,
      elapsed: DateTime.now().difference(_started),
    );
  }
}

/// 采集进程运行器(拍摄/录屏共用;桌面 ffmpeg 采集执行,与桌面转码
/// ProcessEngine 同型 —— Process.start 直传参数 + 取消终止时序)。
class CaptureProcessRunner {
  CaptureProcessRunner({
    Future<Process> Function(String executable, List<String> args)?
    startProcess,
  }) : _startProcess = startProcess ?? Process.start;

  final Future<Process> Function(String executable, List<String> args)
  _startProcess;

  /// 启动采集会话。
  ///
  /// [cancelToken] 取消协商:[onCancel] 注册会话取消(终止 + 删半成品);
  /// [onLog] 收到 ffmpeg 输出行(诊断日志)。stdout/stderr 双流必消费,
  /// 防管道缓冲填满阻塞进程。
  Future<CaptureSession> start({
    required List<String> args,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(String line)? onLog,
  }) async {
    final process = await _startProcess('ffmpeg', args);
    final session = CaptureSession._(
      process,
      ProcessHandleImpl(process),
      outputPath,
      DateTime.now(),
    );
    // stdout:优先原始字节监听(截帧预览 JPEG 分割);诊断日志按行
    // 语义(LineSplitter 状态化拼接跨块行);二进制块(JPEG 帧)跳过
    process.stdout.listen((chunk) {
      final bytes = Uint8List.fromList(chunk);
      session.onStdoutBytes?.call(bytes);
      if (onLog != null) {
        try {
          for (final line in const LineSplitter().convert(
            const Utf8Decoder().convert(bytes),
          )) {
            onLog(line);
          }
        } on FormatException {
          // 二进制 stdout(截帧预览):跳过诊断日志
        }
      }
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          session.addStderrLine(line);
          onLog?.call(line);
        });
    cancelToken?.onCancel(() => unawaited(session.cancel()));
    return session;
  }
}

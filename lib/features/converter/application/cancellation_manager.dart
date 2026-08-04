import 'dart:async';
import 'dart:io';

import '../../../domain/repository_interfaces/ffmpeg_engine.dart';

/// 子进程句柄抽象(便于单测注入,Fake 控制退出状态)。
abstract interface class ProcessHandle {
  bool get hasExited;

  /// 请求终止;[force] = true 时强杀(SIGKILL)。
  Future<void> kill({bool force});
}

/// [ProcessHandle] 的 dart:io 实现。
///
/// dart:io 无同步退出状态 API,经订阅 [Process.exitCode] 维护标志
/// (进程退出无论成败均置 true,支持同步快照读取)。
class ProcessHandleImpl implements ProcessHandle {
  ProcessHandleImpl(this._process) {
    _process.exitCode.then(
      (_) => _exited = true,
      onError: (_) => _exited = true,
    );
  }

  final Process _process;
  bool _exited = false;

  @override
  bool get hasExited => _exited;

  @override
  Future<void> kill({bool force = false}) async {
    if (_exited) return;
    if (force) {
      _process.kill(ProcessSignal.sigkill);
    } else {
      _process.kill();
    }
  }
}

/// 终止子进程(docs/08 §8.3.6 取消动作 ②③④):
/// kill → 等待退出([forceKillTimeout] 内轮询)→ 未退出则强杀。
///
/// 幂等:已退出进程直接返回;[delay] 可注入(测试加速)。
Future<void> terminateProcess(
  ProcessHandle handle, {
  Duration forceKillTimeout = const Duration(seconds: 3),
  Future<void> Function(Duration)? delay,
}) async {
  if (handle.hasExited) return;
  await handle.kill();
  const pollInterval = Duration(milliseconds: 50);
  var waited = Duration.zero;
  while (!handle.hasExited && waited < forceKillTimeout) {
    await (delay ?? Future<void>.delayed)(pollInterval);
    waited += pollInterval;
  }
  if (!handle.hasExited) {
    await handle.kill(force: true);
  }
}

/// 取消管理器(§8.3.6):统一取消入口 + 幂等临时文件清理。
///
/// 职责:① 标记 [CancelToken](触发引擎侧进程终止时序,见
/// [terminateProcess])+ ⑤ 幂等清理临时文件;任何路径重复调用无副作用。
class CancellationManager {
  CancellationManager({
    required CancelToken token,
    required List<String> tempFiles,
    required String workDir,
  }) : _token = token,
       _tempFiles = List.of(tempFiles),
       _workDir = workDir;

  final CancelToken _token;
  final List<String> _tempFiles;
  final String _workDir;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// 取消(幂等):标记令牌 → 幂等清理临时文件。
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    _token.cancel();
    await cleanupTempFiles();
  }

  /// 幂等清理:临时文件存在才删;工作目录清空后移除目录。
  Future<void> cleanupTempFiles() async {
    for (final path in _tempFiles) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final dir = Directory(_workDir);
    if (await dir.exists()) {
      final remaining = dir.listSync();
      if (remaining.isEmpty) {
        await dir.delete();
      }
    }
  }
}

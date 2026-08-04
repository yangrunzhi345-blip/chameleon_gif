/// 取消令牌:原子标志 + 取消回调(幂等,重复 cancel 无副作用)。
///
/// 转换中各方(引擎轮询、编排层短路)都只读 [isCancelled];主动取消经
/// [onCancel] 注册进程终止回调(ProcessEngine 在启动后注册 kill)。
class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  /// 标记取消并同步触发已注册监听(幂等:仅首次生效)。
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 注册取消回调;token 已取消时立即执行一次。
  void onCancel(void Function() listener) {
    _listeners.add(listener);
    if (_cancelled) listener();
  }
}

/// 单条转换请求(§8.3.1)。
class ConvertRequest {
  const ConvertRequest({
    required this.command,
    required this.workDir,
    required this.tempFiles,
  });

  /// 命令参数列表(不含可执行名,引擎按平台前缀执行)。
  final List<String> command;

  /// 工作目录(临时产物目录,含 taskId)。
  final String workDir;

  /// 需清理的临时文件绝对路径列表(取消/结束后删除)。
  final List<String> tempFiles;
}

/// 单条命令执行结果(§8.3.1)。
class ConvertResult {
  const ConvertResult({
    required this.exitCode,
    required this.elapsed,
    this.outputSizeBytes,
    this.cancelled = false,
  });

  /// 进程退出码(取消判定不以退出码为准,见 [cancelled])。
  final int exitCode;

  /// 本次命令耗时(多条命令由编排层累加)。
  final Duration elapsed;

  /// 输出文件字节数(存在时)。
  final int? outputSizeBytes;

  /// 是否因取消而终止(跨平台信号码不一,以令牌为准)。
  final bool cancelled;
}

/// FFmpeg 引擎端口(§8.3.1,低级执行器;编排见 [FFmpegService])。
///
/// 实现按平台:桌面 [ProcessEngine](dart:io Process 调系统二进制),
/// Android [FfmpegKitEngine](ffmpeg_kit 内嵌库)。仅负责"执行一条命令并
/// 透出行";命令构造/进度解析/错误分类全部在应用层纯函数。
abstract interface class FFmpegEngine {
  /// 执行单条命令。
  ///
  /// [onProgress] 收到 stdout 原始行(引擎不做解析,编排层持 ProgressParser);
  /// [onLog] 收到 stderr 原始行。取消经 [cancelToken] 协商:引擎注册
  /// 进程终止回调并轮询令牌,终止后返回 [ConvertResult.cancelled] = true。
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  });
}

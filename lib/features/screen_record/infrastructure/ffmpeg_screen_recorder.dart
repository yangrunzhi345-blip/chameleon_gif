import 'dart:async';
import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/screen_recorder_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/camera/infrastructure/capture_committer.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import '../application/record_command_builder.dart';
import '../application/record_environment_detector.dart';

/// 桌面录屏实现(系统 ffmpeg 采集,docs/19 里程碑 2/3)。
///
/// 采集方式按环境选型:Windows `-f gdigrab`(恒可用);Linux X11
/// `-f x11grab`;Linux Wayland `-f pipewire`(ffmpeg 6.1+,依赖
/// xdg-desktop-portal 授权弹窗)。与桌面转码同型:Process 执行 +
/// [CancelToken] 取消。产物落位复用 CaptureCommitter(仅素材目录,
/// 无相册语义)。结束信号三态与相机端口同构:手动停(保存)/
/// `-t` 超时自退(保存)/ 取消(删半成品)。
class FfmpegScreenRecorder implements ScreenRecorderPort {
  FfmpegScreenRecorder({
    required this.capturesDir,
    required this.tempDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
    Future<bool> Function(String device)? ffmpegHasDevice,
    CaptureProcessRunner? runner,
    RecordCommandBuilder? commandBuilder,
    RecordEnvironment? environment,
  }) : _logger = logger,
       _ffmpegHasDevice = ffmpegHasDevice ?? _runFfmpegHasDevice,
       _committer = CaptureCommitter(
         adapter: adapter,
         capturesDir: capturesDir,
       ),
       _runner = runner ?? CaptureProcessRunner(),
       _commandBuilder = commandBuilder ?? const RecordCommandBuilder(),
       _environmentOverride = environment;

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`)。
  final Directory capturesDir;

  /// 私有 tmp 目录(录制中产物,落位后清理)。
  final Directory tempDir;

  final AppLogger _logger;
  final Future<bool> Function(String device) _ffmpegHasDevice;
  final CaptureCommitter _committer;
  final CaptureProcessRunner _runner;
  final RecordCommandBuilder _commandBuilder;

  /// 当前录制会话就绪信号(requestStop 等会话创建完成;串行录制)。
  Completer<CaptureSession?>? _sessionReady;

  /// 环境注入(测试);null = 运行时探测。
  final RecordEnvironment? _environmentOverride;

  /// 环境探测:Windows 恒 gdigrab;Linux 读会话环境变量(XDG_SESSION_TYPE
  /// 判定 X11/Wayland,DISPLAY 供 x11grab 输入)。
  RecordEnvironment get _environment {
    final override = _environmentOverride;
    if (override != null) return override;
    if (Platform.isWindows) {
      return const RecordEnvironment(method: RecordCaptureMethod.gdigrab);
    }
    final env = Platform.environment;
    return detectRecordEnvironment(
      sessionType: env['XDG_SESSION_TYPE'],
      display: env['DISPLAY'],
    );
  }

  /// 轻探测:ffmpeg -devices 是否包含指定采集输入(毫秒级,不阻塞入口;
  /// 不做带超时的采集探测 —— portal 存在时该探测会弹系统共享选择框,
  /// 交互副作用不可接受)。
  static Future<bool> _runFfmpegHasDevice(String device) async {
    try {
      final result = await Process.run('ffmpeg', ['-hide_banner', '-devices']);
      return result.exitCode == 0 && result.stdout.toString().contains(device);
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<List<RecordTarget>> enumerateTargets() async {
    // MVP 全屏单目标(窗口枚举延后,依赖 Windows 原生代码)
    return const [RecordTarget(id: '0', title: '全屏')];
  }

  @override
  Future<RecordCapabilities> queryCapabilities() async {
    final env = _environment;
    switch (env.method) {
      case RecordCaptureMethod.x11grab:
        return await _ffmpegHasDevice('x11grab')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.x11grab,
                supportsRegions: true,
                supportsCursorToggle: true,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.x11grab,
                hint: '系统 ffmpeg 缺少 x11grab 输入,请安装完整版 ffmpeg',
              );
      case RecordCaptureMethod.pipewire:
        return await _ffmpegHasDevice('pipewire')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.pipewire,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.pipewire,
                hint:
                    '当前 Wayland 会话缺少屏幕共享支持:系统 ffmpeg 未编译 '
                    'pipewire 输入。请安装支持 pipewire 的 ffmpeg 与 '
                    'xdg-desktop-portal,或切换到 X11 会话',
              );
      case RecordCaptureMethod.gdigrab:
        return await _ffmpegHasDevice('gdigrab')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.gdigrab,
                supportsRegions: true,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.gdigrab,
                hint: '系统 ffmpeg 缺少 gdigrab 输入,请安装完整版 ffmpeg',
              );
      case RecordCaptureMethod.none:
        return const RecordCapabilities(
          screenCaptureAvailable: false,
          hint: '未检测到可用的录屏环境',
        );
    }
  }

  @override
  Future<CaptureResult> record({
    required RecordParams params,
    CancelToken? cancelToken,
  }) async {
    final env = _environment;
    final kind = switch (env.method) {
      RecordCaptureMethod.x11grab => RecordCommandKind.x11grab,
      RecordCaptureMethod.pipewire => RecordCommandKind.pipewire,
      RecordCaptureMethod.gdigrab => RecordCommandKind.gdigrab,
      RecordCaptureMethod.none => throw const CaptureException(
        errorCode: 'GIF_RECORD_UNAVAILABLE',
        userMessage:
            '当前环境不支持屏幕录制:请切换到 X11 会话,'
            '或安装并运行 xdg-desktop-portal 后重试',
      ),
    };
    final fileName = buildCaptureFilename(DateTime.now());
    final tmpPath = '${tempDir.path}/$fileName';
    final args = _commandBuilder.build(
      params: params,
      kind: kind,
      display: env.display,
      outputPath: tmpPath,
    );
    _logger.i('录屏启动: ${env.method}\nffmpeg ${args.join(' ')}');
    final ready = Completer<CaptureSession?>();
    _sessionReady = ready;
    final CaptureSession session;
    try {
      session = await _runner.start(
        args: args,
        outputPath: tmpPath,
        cancelToken: cancelToken,
        onLog: (line) => _logger.d('录屏 ffmpeg: $line'),
      );
    } catch (e, st) {
      _logger.e('录屏进程启动失败', error: e, stackTrace: st);
      ready.complete(null);
      await _committer.discardTmp(tmpPath);
      throw CaptureException(
        errorCode: 'GIF_RECORD_ERROR',
        userMessage: '录屏启动失败,请确认 FFmpeg 已安装',
        cause: e,
      );
    }
    ready.complete(session);
    // 时长兜底 watchdog:`-t` 失效时强制停(保存),防进程挂死泄漏
    final watchdog = Timer(
      Duration(milliseconds: params.maxDurationMs + 5000),
      () => session.stop(),
    );
    final outcome = await session.waitExit();
    watchdog.cancel();
    _sessionReady = null;
    if (outcome.cancelled) {
      throw const CaptureCancelledException(); // 半成品已删,不落位
    }
    if (outcome.exitCode != 0 && !outcome.stoppedByRequest) {
      await _committer.discardTmp(tmpPath);
      // 流派发异步:进程已退出,冲刷事件循环确保 stderr 尾部就绪
      await Future<void>.delayed(Duration.zero);
      throw _mapRecordError(session.stderrTail, env.method);
    }
    _logger.i(
      '录屏完成: $tmpPath ${outcome.elapsed.inMilliseconds}ms '
      'exit=${outcome.exitCode}',
    );
    return await _committer.commit(
      tmpPath: tmpPath,
      fileName: fileName,
      durationMs: outcome.elapsed.inMilliseconds,
    );
  }

  /// stderr 尾部 + 采集方式 → 用户可读中文错误。
  CaptureException _mapRecordError(
    List<String> stderrTail,
    RecordCaptureMethod method,
  ) {
    final tail = stderrTail.join('\n');
    String userMessage;
    if (method == RecordCaptureMethod.pipewire) {
      userMessage =
          'Wayland 录屏失败:请确认已安装并运行 xdg-desktop-portal'
          '(录屏需系统授权),或切换到 X11 会话';
    } else if (tail.contains('Could not open display') ||
        tail.contains('cannot open display')) {
      userMessage = '无法连接显示器,请确认桌面环境可用后重试';
    } else if (tail.contains('Permission denied')) {
      userMessage = '无权限访问屏幕,请确认桌面会话权限正常';
    } else {
      final lastLine = stderrTail.isEmpty ? '' : stderrTail.last.trim();
      userMessage = lastLine.isEmpty ? '录屏失败,请重试' : '录屏失败:$lastLine';
    }
    return CaptureException(
      errorCode: 'GIF_RECORD_ERROR',
      userMessage: userMessage,
    );
  }

  @override
  Future<void> requestStop() async {
    // 等待会话就绪(异步启动期间按停止不丢信号);启动失败 complete(null)
    final ready = _sessionReady;
    if (ready == null) return;
    final session = await ready.future;
    await session?.stop(); // SIGTERM 优雅封口(保存)
  }
}

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

  /// 有效产物最小字节数(0 帧 wf-recorder 产物约 262B,截断 moov 损坏)。
  static const _minValidBytes = 4096;

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

  /// 独立工具可用性(wf-recorder 等;PATH 探测,轻量)。
  static Future<bool> _toolAvailable(String name) async {
    try {
      final result = await Process.run('which', [name]);
      return result.exitCode == 0;
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
      case RecordCaptureMethod.wfRecorder:
        // Wayland:wlr-screencopy 直接抓屏(无 portal 弹窗);探测
        // wf-recorder 二进制存在;光标恒带(无开关)
        return await _toolAvailable('wf-recorder')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.wfRecorder,
                supportsRegions: true,
                supportsCursorToggle: false,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.wfRecorder,
                hint:
                    '当前 Wayland 会话缺少屏幕录制工具:请安装 '
                    'wf-recorder(支持 wlr-screencopy 的合成器,如 niri)',
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
      RecordCaptureMethod.wfRecorder => RecordCommandKind.wfRecorder,
      RecordCaptureMethod.gdigrab => RecordCommandKind.gdigrab,
      RecordCaptureMethod.none => throw const CaptureException(
        errorCode: 'GIF_RECORD_UNAVAILABLE',
        userMessage:
            '当前环境不支持屏幕录制,请切换到 X11 会话或安装 '
            'wf-recorder 后重试',
      ),
    };
    // 可执行名:Wayland 走 wf-recorder,其余 ffmpeg
    final executable = kind == RecordCommandKind.wfRecorder
        ? 'wf-recorder'
        : 'ffmpeg';
    final fileName = buildCaptureFilename(DateTime.now());
    final tmpPath = '${tempDir.path}/$fileName';
    final args = _commandBuilder.build(
      params: params,
      kind: kind,
      display: env.display,
      outputPath: tmpPath,
    );
    _logger.i('录屏启动: ${env.method}\n$executable ${args.join(' ')}');
    final ready = Completer<CaptureSession?>();
    _sessionReady = ready;
    final CaptureSession session;
    try {
      session = await _runner.start(
        args: args,
        outputPath: tmpPath,
        executable: executable,
        cancelToken: cancelToken,
        onLog: (line) => _logger.d('录屏 $executable: $line'),
      );
    } catch (e, st) {
      _logger.e('录屏进程启动失败', error: e, stackTrace: st);
      ready.complete(null);
      await _committer.discardTmp(tmpPath);
      throw CaptureException(
        errorCode: 'GIF_RECORD_ERROR',
        userMessage: '录屏启动失败,请确认 $executable 已安装',
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
    // 0 帧产物校验:wf-recorder 极短录制(0 帧)SIGTERM 封口会留下
    // ftyp+截断 moov 的损坏 mp4(实测 262B,ffprobe 报 Invalid data);
    // ffmpeg 分支 0 帧自动删空输出,不受影响。删除并友好提示,避免
    // 自动导入时出现误导性的"文件损坏或格式异常"。
    final tmpFile = File(tmpPath);
    if (!await tmpFile.exists() || await tmpFile.length() < _minValidBytes) {
      await _committer.discardTmp(tmpPath);
      throw const CaptureException(
        errorCode: 'GIF_RECORD_TOO_SHORT',
        userMessage: '录制时间过短,未生成有效内容,请重新录制',
      );
    }
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
    if (method == RecordCaptureMethod.wfRecorder) {
      userMessage =
          'Wayland 录屏失败:请确认当前合成器支持 '
          'wlr-screencopy(如 niri/wlroots),且 wf-recorder 已安装';
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

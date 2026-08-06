import 'dart:async';
import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import '../application/camera_command_builder.dart';
import '../application/v4l2_device_parser.dart';
import 'capture_committer.dart';

/// 桌面相机拍摄实现(ffmpeg 采集 + v4l2-ctl 控制,docs/18 里程碑 2/3)。
///
/// 采集:Linux `-f v4l2` / Windows `-f dshow`(系统 ffmpeg 二进制,与桌面
/// 转码 ProcessEngine 同型);控制:Linux v4l2-ctl(第二档,能力探测驱动),
/// Windows 第一版不设(无 COM 插件,仅基础档)。
/// 盲拍:无实时取景([previewSupported]=false),录完在工作台回放确认
/// (docs/18 D4)。
class FfmpegCameraPort implements CameraPort {
  FfmpegCameraPort({
    required this.capturesDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
    CaptureProcessRunner? runner,
    CameraCommandBuilder? commandBuilder,
  }) : _adapter = adapter,
       _logger = logger,
       _committer = CaptureCommitter(
         adapter: adapter,
         capturesDir: capturesDir,
       ),
       _runner = runner ?? CaptureProcessRunner(),
       _commandBuilder = commandBuilder ?? const CameraCommandBuilder();

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`;CaptureCommitter 使用)。
  final Directory capturesDir;

  final PlatformAdapter _adapter;
  final AppLogger _logger;
  final CaptureCommitter _committer;
  final CaptureProcessRunner _runner;
  final CameraCommandBuilder _commandBuilder;

  /// 当前采集会话就绪信号(requestStop 须等待会话创建完成 ——
  /// capture 异步启动期间页面即可按停止;串行拍摄,UI 状态机保证)。
  Completer<CaptureSession?>? _sessionReady;

  @override
  bool get previewSupported => false; // 桌面盲拍

  @override
  Future<List<CameraDevice>> enumerateDevices() async {
    if (Platform.isWindows) {
      // dshow:ffmpeg -sources dshow 枚举(零 COM;设备名即输入标识)
      final names = await _runFfmpegSourcesDshow();
      return [for (final name in names) CameraDevice(id: name, name: name)];
    }
    // Linux:优先 v4l2-ctl(--list-devices + get-fmt-video 探活过滤 meta
    // 节点,实测同一摄像头双节点 /dev/video0+1);v4l2-ctl 缺失降级
    // ffmpeg -sources v4l2(不区分 meta,采集失败由错误映射兜底)
    final entries = await _enumerateV4l2();
    return [
      for (final e in entries)
        CameraDevice(id: e.node, name: '${e.name} (${e.node})'),
    ];
  }

  /// v4l2-ctl 主路径 + ffmpeg -sources 降级路径。
  Future<List<V4l2DeviceEntry>> _enumerateV4l2() async {
    try {
      final result = await Process.run('v4l2-ctl', ['--list-devices']);
      if (result.exitCode == 0 &&
          result.stdout.toString().contains('/dev/video')) {
        final entries = parseV4l2ListDevices(result.stdout.toString());
        if (entries.isNotEmpty) {
          final alive = <V4l2DeviceEntry>[];
          for (final e in entries) {
            final probe = await Process.run('v4l2-ctl', [
              '-d',
              e.node,
              '--get-fmt-video',
            ]);
            if (probe.exitCode == 0) alive.add(e);
          }
          if (alive.isNotEmpty) return alive;
        }
      }
    } on ProcessException catch (e, st) {
      _logger.w('v4l2-ctl 枚举失败(降级 ffmpeg -sources)', error: e, stackTrace: st);
    }
    try {
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-sources',
        'v4l2',
      ]);
      if (result.exitCode == 0) {
        final entries = parseFfmpegSourcesV4l2(result.stdout.toString());
        if (entries.isNotEmpty) return entries;
      }
    } on ProcessException catch (e, st) {
      _logger.w('ffmpeg -sources v4l2 枚举失败', error: e, stackTrace: st);
    }
    return const [];
  }

  /// Windows dshow 设备枚举(ffmpeg -sources dshow;解析失败返回空)。
  Future<List<String>> _runFfmpegSourcesDshow() async {
    try {
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-sources',
        'dshow',
      ]);
      if (result.exitCode != 0) return const [];
      return parseFfmpegSourcesDshow(result.stdout.toString());
    } on ProcessException catch (e, st) {
      _logger.w('ffmpeg -sources dshow 枚举失败', error: e, stackTrace: st);
      return const [];
    }
  }

  @override
  Future<CameraCapabilities> queryCapabilities(String deviceId) async {
    // WP6 落地:v4l2-ctl -l 控制项 + --list-formats-ext 分辨率/帧率解析
    return const CameraCapabilities();
  }

  @override
  Future<void> applyParams(CaptureParams params) async {
    // WP6 落地:v4l2-ctl --set-ctrl 批量应用第二档控制项
  }

  @override
  Future<CaptureResult> capture({
    required CaptureParams params,
    CancelToken? cancelToken,
  }) async {
    // 设备解析:配置缺失 → 枚举首个可用(拔插后配置失效兜底;
    // 配置了但已拔出 → ffmpeg 启动报错,由错误映射提示)
    final deviceId = params.deviceId ?? await _firstAvailableDeviceId();
    if (deviceId == null) {
      throw const CaptureException(
        errorCode: 'GIF_CAPTURE_UNAVAILABLE',
        userMessage: '未检测到摄像头,请连接摄像头后重试',
      );
    }
    final fileName = buildCaptureFilename(DateTime.now());
    final tmpPath = '${_adapter.systemTempDir}/$fileName';
    final args = _commandBuilder.build(
      params: params,
      kind: Platform.isWindows ? CameraInputKind.dshow : CameraInputKind.v4l2,
      input: deviceId,
      outputPath: tmpPath,
    );
    _logger.i('拍摄启动: $deviceId\nffmpeg ${args.join(' ')}');
    final ready = Completer<CaptureSession?>();
    _sessionReady = ready;
    final CaptureSession session;
    try {
      session = await _runner.start(
        args: args,
        outputPath: tmpPath,
        cancelToken: cancelToken,
        onLog: (line) => _logger.d('拍摄 ffmpeg: $line'),
      );
    } catch (e, st) {
      _logger.e('拍摄进程启动失败', error: e, stackTrace: st);
      ready.complete(null);
      await _committer.discardTmp(tmpPath);
      throw CaptureException(
        errorCode: 'GIF_CAPTURE_CAMERA_ERROR',
        userMessage: '拍摄启动失败,请确认 FFmpeg 已安装',
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
      throw _mapCaptureError(session.stderrTail);
    }
    _logger.i(
      '拍摄完成: $tmpPath ${outcome.elapsed.inMilliseconds}ms '
      'exit=${outcome.exitCode}',
    );
    return await _committer.commit(
      tmpPath: tmpPath,
      fileName: fileName,
      durationMs: outcome.elapsed.inMilliseconds,
    );
  }

  /// 首个可用设备(配置缺失时兜底;无设备返回 null)。
  Future<String?> _firstAvailableDeviceId() async {
    final devices = await enumerateDevices();
    return devices.isEmpty ? null : devices.first.id;
  }

  /// stderr 尾部 → 用户可读中文错误(不泄露原始路径)。
  CaptureException _mapCaptureError(List<String> stderrTail) {
    final tail = stderrTail.join('\n');
    final lastLine = stderrTail.isEmpty ? '' : stderrTail.last.trim();
    String userMessage;
    if (tail.contains('Permission denied')) {
      userMessage = '无权限访问摄像头(请确认用户属于 video 组)';
    } else if (tail.contains('Device or resource busy')) {
      userMessage = '摄像头被其他程序占用,请关闭占用程序后重试';
    } else if (tail.contains('No such file') ||
        tail.contains('No such device')) {
      userMessage = '摄像头设备不可用,请重新选择设备';
    } else if (lastLine.isEmpty) {
      userMessage = '拍摄失败,请重试';
    } else {
      userMessage = '拍摄失败:$lastLine';
    }
    return CaptureException(
      errorCode: 'GIF_CAPTURE_CAMERA_ERROR',
      userMessage: userMessage,
    );
  }

  @override
  Future<void> requestStop() async {
    // 等待会话就绪(capture 异步启动期间按停止不丢信号);启动失败时
    // complete(null),stop 无操作(录制由启动失败异常兜底)
    final ready = _sessionReady;
    if (ready == null) return;
    final session = await ready.future;
    await session?.stop(); // SIGTERM 优雅封口(保存)
  }
}

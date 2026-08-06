import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
import '../application/jpeg_frame_splitter.dart';
import '../application/v4l2_controls_parser.dart';
import '../application/v4l2_device_parser.dart';
import '../application/v4l2_formats_parser.dart';
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

  /// 预览会话(ffmpeg 截帧进程;录制期间暂停,结束后恢复)。
  CaptureSession? _previewSession;

  /// 预览帧流(JPEG 帧;录制期间关闭,结束后重建)。
  StreamController<Uint8List>? _previewFrames;

  /// 预览会话参数(幂等判定 + 录制后恢复)。
  CaptureParams? _previewParams;

  /// JPEG 帧分割器(预览 stdout → 完整帧)。
  final _frameSplitter = JpegFrameSplitter();

  /// 最近一帧(新订阅者补发:录制恢复/重连立即有画面,broadcast 无缓冲)。
  Uint8List? _latestPreviewFrame;

  @override
  bool get previewSupported => true; // 桌面截帧预览(ffmpeg image2pipe)

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

  /// 能力缓存(会话级;applyParams 后失效 —— active 联动重探)。
  CameraCapabilities? _capsCache;
  String? _capsDeviceId;

  @override
  Future<CameraCapabilities> queryCapabilities(String deviceId) async {
    final cached = _capsCache;
    if (cached != null && _capsDeviceId == deviceId) return cached;
    // Windows 第一版无第二档(无 COM 控制插件)→ 默认能力(仅基础档)
    if (Platform.isWindows) return const CameraCapabilities();
    try {
      final controlsResult = await Process.run('v4l2-ctl', [
        '-d',
        deviceId,
        '-L',
      ]);
      final formatsResult = await Process.run('v4l2-ctl', [
        '-d',
        deviceId,
        '--list-formats-ext',
      ]);
      final controls = controlsResult.exitCode == 0
          ? parseV4l2Controls(controlsResult.stdout.toString())
          : const <CameraControlCapability>[];
      final formats = formatsResult.exitCode == 0
          ? parseV4l2FormatsExt(formatsResult.stdout.toString())
          : const <V4l2FormatEntry>[];
      // 分辨率候选:MJPG 压缩流优先(原始流带宽大,同尺寸低帧率);
      // 去重(不同格式同尺寸)后按出现顺序(MJPG 最大尺寸在前)
      final mjpg = formats.where((f) => f.format == 'MJPG').toList();
      final preferred = mjpg.isNotEmpty ? mjpg : formats;
      final resolutions = <CaptureResolution>[];
      for (final f in preferred) {
        final res = CaptureResolution(width: f.width, height: f.height);
        if (!resolutions.contains(res)) resolutions.add(res);
      }
      final caps = CameraCapabilities(
        supportsResolution: resolutions.isNotEmpty,
        supportedResolutions: resolutions,
        controls: controls,
      );
      _capsCache = caps;
      _capsDeviceId = deviceId;
      return caps;
    } on ProcessException catch (e, st) {
      _logger.w('v4l2 能力探测失败($deviceId)', error: e, stackTrace: st);
      return const CameraCapabilities();
    }
  }

  @override
  Future<void> applyParams(CaptureParams params) async {
    // Windows 第一版无第二档(无 COM)→ 仅采集基础参数
    if (Platform.isWindows) return;
    final controls = params.v4l2Controls;
    final deviceId = params.deviceId;
    if (controls.isEmpty || deviceId == null) return;
    // 与能力对齐:跳过设备不存在的控制项与 inactive 项(自动模式联动)
    final caps = await queryCapabilities(deviceId);
    final known = {for (final c in caps.controls) c.id: c};
    final pairs = <String>[];
    for (final entry in controls.entries) {
      final cap = known[entry.key];
      if (cap == null || !cap.active) continue;
      pairs.add('${entry.key}=${entry.value}');
    }
    if (pairs.isEmpty) return;
    try {
      final result = await Process.run('v4l2-ctl', [
        '-d',
        deviceId,
        '--set-ctrl',
        pairs.join(','),
      ]);
      if (result.exitCode != 0) {
        _logger.w('v4l2-ctl --set-ctrl 失败: ${result.stderr}');
      }
    } on ProcessException catch (e, st) {
      _logger.w('v4l2-ctl --set-ctrl 调用失败', error: e, stackTrace: st);
      return;
    }
    // 应用后失效缓存:下次探测刷新 active 联动(如自动白平衡关闭后
    // 色温项从 inactive 恢复可调)
    _capsCache = null;
    _capsDeviceId = null;
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
    // 预览激活 → 录制命令双输出(文件 + 预览帧管道):录制进程接替
    // 预览进程输出帧流,录制中实时预览持续(方案 C+ 实测);未预览 →
    // 单文件(现状契约)
    final previewFrames = _previewFrames;
    final args = previewFrames != null
        ? _commandBuilder.buildWithPreview(
            params: params,
            kind: Platform.isWindows
                ? CameraInputKind.dshow
                : CameraInputKind.v4l2,
            input: deviceId,
            outputPath: tmpPath,
          )
        : _commandBuilder.build(
            params: params,
            kind: Platform.isWindows
                ? CameraInputKind.dshow
                : CameraInputKind.v4l2,
            input: deviceId,
            outputPath: tmpPath,
          );
    _logger.i('拍摄启动: $deviceId\nffmpeg ${args.join(' ')}');
    final ready = Completer<CaptureSession?>();
    _sessionReady = ready;
    final CaptureSession session;
    // 录制前停预览进程(设备独占);**保留帧流** —— 录制进程 stdout
    // 接替输出(录制中实时预览);结束后 _restorePreview 恢复预览进程
    if (previewFrames != null) await _stopPreviewProcess();
    try {
      session = await _runner.start(
        args: args,
        outputPath: tmpPath,
        cancelToken: cancelToken,
        onLog: (line) => _logger.d('拍摄 ffmpeg: $line'),
      );
      if (previewFrames != null) {
        // 录制进程预览管道 → 同一帧流(分割器与预览进程共用)
        _frameSplitter.clear();
        session.onStdoutBytes = (chunk) {
          for (final frame in _frameSplitter.addChunk(chunk)) {
            _latestPreviewFrame = frame;
            if (!previewFrames.isClosed) previewFrames.add(frame);
          }
        };
      }
    } catch (e, st) {
      _logger.e('拍摄进程启动失败', error: e, stackTrace: st);
      ready.complete(null);
      await _committer.discardTmp(tmpPath);
      await _restorePreview();
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
    final CaptureOutcome outcome;
    try {
      outcome = await session.waitExit();
    } finally {
      watchdog.cancel();
      _sessionReady = null;
    }
    if (outcome.cancelled) {
      await _restorePreview();
      throw const CaptureCancelledException(); // 半成品已删,不落位
    }
    if (outcome.exitCode != 0 && !outcome.stoppedByRequest) {
      await _committer.discardTmp(tmpPath);
      // 流派发异步:进程已退出,冲刷事件循环确保 stderr 尾部就绪
      await Future<void>.delayed(Duration.zero);
      await _restorePreview();
      throw _mapCaptureError(session.stderrTail);
    }
    _logger.i(
      '拍摄完成: $tmpPath ${outcome.elapsed.inMilliseconds}ms '
      'exit=${outcome.exitCode}',
    );
    await _restorePreview();
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

  @override
  Future<void> setDevicePortrait(bool portrait) async {
    // 桌面无方向概念(ffmpeg 采集不应用 rotation),no-op
  }

  @override
  Future<Stream<Uint8List>?> startPreview({
    required String deviceId,
    required CaptureParams params,
  }) async {
    // 参数匹配(同设备同帧率)且进程存活 → 复用现有帧流
    final match =
        _previewParams?.deviceId == deviceId &&
        _previewParams?.fps == params.fps;
    final frames = _previewFrames;
    if (match && _previewSession != null && frames != null) {
      return _previewStream(frames);
    }
    await _stopPreviewProcess();
    // 复用现有帧流(录制期间由录制进程接替输出;恢复预览时接续,
    // UI 订阅无需重连);首次则新建
    final controller = frames ?? StreamController<Uint8List>.broadcast();
    final args = _commandBuilder.buildPreview(
      params: params,
      kind: Platform.isWindows ? CameraInputKind.dshow : CameraInputKind.v4l2,
      input: deviceId,
    );
    _logger.i('预览启动: $deviceId\nffmpeg ${args.join(' ')}');
    try {
      final session = await _runner.start(
        args: args,
        outputPath: '', // 截帧管道无输出文件
        onLog: (line) => _logger.d('预览 ffmpeg: $line'),
      );
      // stdout → JPEG 帧分割 → 帧流(broadcast:录制切换期间 UI 持续订阅)
      _frameSplitter.clear();
      _latestPreviewFrame = null;
      session.onStdoutBytes = (chunk) {
        for (final frame in _frameSplitter.addChunk(chunk)) {
          _latestPreviewFrame = frame;
          if (!controller.isClosed) controller.add(frame);
        }
      };
      _previewSession = session;
      _previewFrames = controller;
      // 存储时合并 deviceId(调用方参数可能不含;幂等/恢复判定依赖)
      _previewParams = params.copyWith(deviceId: deviceId);
      return _previewStream(controller);
    } catch (e, st) {
      _logger.e('预览进程启动失败', error: e, stackTrace: st);
      return null;
    }
  }

  /// 停预览进程但**保留帧流**(录制期间由录制进程接替输出;录制后
  /// [startPreview] 接续同一帧流,UI 订阅不断)。
  Future<void> _stopPreviewProcess() async {
    final session = _previewSession;
    _previewSession = null;
    if (session != null) {
      await session.stop(); // SIGTERM(截帧进程无产物,终止即清理)
    }
  }

  @override
  Future<void> stopPreview() async {
    await _stopPreviewProcess();
    // 帧流关闭:监听方(拍摄页)感知预览结束
    final frames = _previewFrames;
    _previewFrames = null;
    _latestPreviewFrame = null;
    if (frames != null && !frames.isClosed) await frames.close();
    // 保留 _previewParams:录制后恢复预览依据(设备/参数变化时覆盖)
  }

  /// 预览帧流包装:新订阅者先补发最近帧(broadcast 无缓冲,
  /// 录制恢复/UI 重连立即有画面),再转发实时帧。
  Stream<Uint8List> _previewStream(StreamController<Uint8List> controller) {
    final latest = _latestPreviewFrame;
    return Stream.multi((emit) {
      if (latest != null) emit.add(latest);
      final sub = controller.stream.listen(
        emit.add,
        onError: emit.addError,
        onDone: emit.close,
      );
      emit.onCancel = sub.cancel;
    });
  }

  /// 录制结束后恢复预览(同设备同参;失败仅日志,不阻塞拍摄流程)。
  Future<void> _restorePreview() async {
    final params = _previewParams;
    final deviceId = params?.deviceId;
    if (params == null || deviceId == null) return;
    try {
      await startPreview(deviceId: deviceId, params: params);
    } catch (e, st) {
      _logger.w('录制后恢复预览失败', error: e, stackTrace: st);
    }
  }
}

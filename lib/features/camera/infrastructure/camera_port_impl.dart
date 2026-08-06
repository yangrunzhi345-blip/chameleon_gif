import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart'
    as domain;
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'capture_committer.dart';

/// Android 相机拍摄实现(camera 插件封装,docs/18 C1-WP2)。
///
/// 会话控制器唯一 owner:取景预览(cameraControllerProvider)与拍摄
/// ([capture])同源复用 [activeController];页面 dispose 经 [releaseController]
/// 释放。错误包装:权限拒绝 → [CapturePermissionDeniedException],
/// 其余插件异常 → [CaptureException](用户可读中文)。
///
/// 录制编排:阻塞式等待,三种结束信号 —— 页面手动停止([stopCapture],
/// 保存)/ 超时(maxDurationMs,保存)/ 取消([cancelToken],不保存)。
///
/// 文档偏差(随提交记录):白平衡色温/ISO 插件无 API → 自动白平衡;
/// FocusMode.continuous → 插件 FocusMode.auto(插件仅 auto/fixed);
/// 素材副本落位素材目录不删(阶段 B 决策 3)。
class CameraPortImpl implements CameraPort {
  CameraPortImpl({
    required this.capturesDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
    Future<List<CameraDescription>> Function()? loadCameras,
    CameraController Function(CameraDescription, int?)? controllerFactory,
  }) : _logger = logger,
       _loadCameras = loadCameras ?? availableCameras,
       _controllerFactory =
           controllerFactory ??
           ((desc, fps) => CameraController(
             desc,
             ResolutionPreset.high,
             enableAudio: false,
             fps: fps,
           )),
       _committer = CaptureCommitter(
         adapter: adapter,
         capturesDir: capturesDir,
       );

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`,阶段 B 决策 3)。
  final Directory capturesDir;

  final AppLogger _logger;
  final Future<List<CameraDescription>> Function() _loadCameras;
  final CameraController Function(CameraDescription, int?) _controllerFactory;
  final CaptureCommitter _committer;

  CameraController? _controller;
  String? _deviceId;
  double? _fps;
  Completer<void>? _stopCompleter;

  /// 当前会话取景控制器(未初始化时为 null;与 [capture] 同源)。
  CameraController? get activeController => _controller;

  /// 懒建 + initialize 会话控制器(默认后置摄像头,enableAudio: false)。
  ///
  /// 幂等:同设备同 fps 复用现有会话;设备切换时重建。初始化失败时
  /// 释放并置 null(错误由 [capture] 出口统一包装)。
  Future<CameraController?> ensureController({
    String? deviceId,
    double? fps,
  }) async {
    final current = _controller;
    if (current != null && _deviceId == deviceId && _fps == fps) {
      return current;
    }
    await releaseController();
    try {
      final desc = await _resolveDescription(deviceId);
      if (desc == null) return null;
      final controller = _controllerFactory(desc, fps?.round());
      await controller.initialize();
      _controller = controller;
      _deviceId = deviceId;
      _fps = fps;
      _logger.i('相机会话就绪: ${desc.name} fps=$fps');
      return controller;
    } catch (e, st) {
      _logger.e('相机初始化失败', error: e, stackTrace: st);
      await releaseController();
      return null;
    }
  }

  /// 释放相机会话(页面 dispose / 设置页会话结束;幂等)。
  Future<void> releaseController() async {
    final current = _controller;
    _controller = null;
    _deviceId = null;
    _fps = null;
    if (current != null) {
      try {
        await current.dispose();
      } catch (e, st) {
        _logger.w('相机会话释放失败', error: e, stackTrace: st);
      }
    }
  }

  /// 手动停止当前录制(保存;录制中由页面停止按钮调用)。
  Future<void> stopCapture() async {
    _stopCompleter?.complete();
  }

  Future<CameraDescription?> _resolveDescription(String? deviceId) async {
    final List<CameraDescription> cameras;
    try {
      cameras = await _loadCameras();
    } on MissingPluginException {
      return null; // 桌面等无相机插件宿主
    }
    if (cameras.isEmpty) return null;
    if (deviceId != null) {
      return cameras.where((c) => c.name == deviceId).firstOrNull;
    }
    // 默认后置;无后置取首个
    return cameras
            .where((c) => c.lensDirection == CameraLensDirection.back)
            .firstOrNull ??
        cameras.first;
  }

  @override
  Future<List<CameraDevice>> enumerateDevices() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await _loadCameras();
    } on MissingPluginException {
      return const []; // 桌面:空列表,页面显示空态
    }
    return [
      for (final c in cameras)
        CameraDevice(
          id: c.name,
          name: c.lensDirection == CameraLensDirection.front
              ? '前置摄像头'
              : '后置摄像头',
        ),
    ];
  }

  @override
  Future<CameraCapabilities> queryCapabilities(String deviceId) async {
    // 探测式会话:逐项 try/catch,失败项降级默认(false/范围默认)
    final controller = await ensureController(deviceId: deviceId);
    if (controller == null) return const CameraCapabilities();
    var caps = const CameraCapabilities();
    try {
      final min = await controller.getMinExposureOffset();
      final max = await controller.getMaxExposureOffset();
      final step = await controller.getExposureOffsetStepSize();
      caps = CameraCapabilities(
        maxDurationMs: 30000,
        supportsFlash: true,
        supportsExposureOffset: true,
        exposureOffsetMin: min,
        exposureOffsetMax: max,
        exposureOffsetStep: step,
        supportsExposureLock: true,
      );
    } catch (e) {
      _logger.w('曝光能力探测失败: $e');
    }
    try {
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      caps = CameraCapabilities(
        maxDurationMs: caps.maxDurationMs,
        supportsFlash: caps.supportsFlash,
        supportsExposureOffset: caps.supportsExposureOffset,
        exposureOffsetMin: caps.exposureOffsetMin,
        exposureOffsetMax: caps.exposureOffsetMax,
        exposureOffsetStep: caps.exposureOffsetStep,
        supportsZoom: true,
        zoomMin: min,
        zoomMax: max,
        supportsExposureLock: caps.supportsExposureLock,
        focusModes: caps.focusModes,
      );
    } catch (e) {
      _logger.w('变焦能力探测失败: $e');
    }
    return caps;
  }

  @override
  Future<void> applyParams(domain.CaptureParams params) async {
    final controller = await ensureController(
      deviceId: params.deviceId,
      fps: params.fps,
    );
    if (controller == null) return;
    // 曝光锁定 → 模式切换(插件无独立曝光锁 API)
    try {
      await controller.setExposureMode(
        params.exposureLock ? ExposureMode.locked : ExposureMode.auto,
      );
    } catch (e) {
      _logger.w('曝光模式设置失败: $e');
    }
    if (params.exposureCompensation != null &&
        params.exposureCompensation != 0) {
      try {
        final min = await controller.getMinExposureOffset();
        final max = await controller.getMaxExposureOffset();
        await controller.setExposureOffset(
          params.exposureCompensation!.clamp(min, max),
        );
      } catch (e) {
        _logger.w('曝光补偿设置失败: $e');
      }
    }
    // 对焦映射:continuous → auto;manual → locked(插件仅 auto/locked,
    // 文档偏差记录)
    try {
      await controller.setFocusMode(
        params.focusMode == domain.FocusMode.manual
            ? FocusMode.locked
            : FocusMode.auto,
      );
    } catch (e) {
      _logger.w('对焦模式设置失败: $e');
    }
    if (params.zoom != null && params.zoom != 1.0) {
      try {
        final min = await controller.getMinZoomLevel();
        final max = await controller.getMaxZoomLevel();
        await controller.setZoomLevel(params.zoom!.clamp(min, max));
      } catch (e) {
        _logger.w('变焦设置失败: $e');
      }
    }
    try {
      await controller.setFlashMode(
        params.flashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      _logger.w('闪光灯设置失败: $e');
    }
  }

  @override
  Future<CaptureResult> capture({
    required domain.CaptureParams params,
    CancelToken? cancelToken,
  }) async {
    final controller = await ensureController(
      deviceId: params.deviceId,
      fps: params.fps,
    );
    if (controller == null) {
      throw const CaptureException(
        errorCode: 'GIF_CAPTURE_UNAVAILABLE',
        userMessage: '相机不可用,请检查相机权限后重试',
      );
    }
    // 录制前重放参数(设置页 live apply 可能因无预览 surface 失效,
    // 拍摄正确性不依赖之)
    await applyParams(params);

    var cancelled = false;
    cancelToken?.onCancel(() {
      cancelled = true;
      _stopCompleter?.complete(); // 取消也唤醒等待(结束信号)
    });
    _stopCompleter = Completer<void>();
    // 超时自动停(保存;上限 maxDurationMs)
    final timer = Timer(
      Duration(milliseconds: params.maxDurationMs),
      () => _stopCompleter?.complete(),
    );
    final started = DateTime.now();
    try {
      await controller.prepareForVideoRecording();
      await controller.startVideoRecording();
      // 阻塞等待三种结束信号:手动停止(stopCapture)/ 超时 / 取消
      await _stopCompleter!.future;
      timer.cancel();
      final file = await controller.stopVideoRecording();
      final elapsed = DateTime.now().difference(started);
      if (cancelled || (cancelToken?.isCancelled ?? false)) {
        // 用户取消:清理 tmp,不落位
        await _committer.discardTmp(file.path);
        throw const CaptureCancelledException();
      }
      _logger.i('拍摄完成: ${file.path} ${elapsed.inMilliseconds}ms');
      return await _committer.commit(
        tmpPath: file.path,
        fileName: buildCaptureFilename(DateTime.now()),
        durationMs: elapsed.inMilliseconds,
      );
    } on CaptureException {
      rethrow;
    } on CameraException catch (e, st) {
      timer.cancel();
      _logger.e('拍摄失败', error: e, stackTrace: st);
      if (e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt') {
        throw const CapturePermissionDeniedException(
          userMessage: '相机权限被拒绝,请前往系统设置允许相机权限后重试',
        );
      }
      throw CaptureException(
        errorCode: 'GIF_CAPTURE_CAMERA_ERROR',
        userMessage: '相机不可用:${e.description ?? '未知错误'}',
        cause: e,
      );
    } catch (e, st) {
      timer.cancel();
      _logger.e('拍摄失败(未预期)', error: e, stackTrace: st);
      throw CaptureException(
        errorCode: 'GIF_CAPTURE_CAMERA_ERROR',
        userMessage: '拍摄失败,请重试',
        cause: e,
      );
    } finally {
      _stopCompleter = null;
    }
  }
}

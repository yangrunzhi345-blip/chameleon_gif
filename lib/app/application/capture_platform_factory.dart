import 'dart:io' show Directory, Platform;

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/screen_recorder_port.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_port_impl.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/ffmpeg_screen_recorder.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/screen_recorder_port_impl.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 采集端口平台选型工厂(组合根;docs/18 §4.2 + docs/19 §2.3 的
/// "PlatformAdapter 选型"意图落地于 app 层 —— PlatformAdapter 位于
/// shared,禁止反向依赖 features,故工厂不置于 adapter 内)。
///
/// Android → camera 插件 / MediaProjection 原生桥;桌面 → ffmpeg 采集
/// (v4l2/dshow 拍摄、gdigrab/x11grab/pipewire 录屏,系统二进制)。
class CapturePlatformFactory {
  CapturePlatformFactory({
    required PlatformAdapter adapter,
    required AppLogger logger,
    bool? isAndroid,
  }) : _adapter = adapter,
       _logger = logger,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  final PlatformAdapter _adapter;
  final AppLogger _logger;
  final bool _isAndroid;

  /// 相机拍摄端口(Android = CameraPortImpl 插件闭环;桌面 = FfmpegCameraPort)。
  CameraPort createCameraPort({required Directory capturesDir}) {
    if (_isAndroid) {
      return CameraPortImpl(
        capturesDir: capturesDir,
        adapter: _adapter,
        logger: _logger,
        // 素材竖屏化(media_kit 不应用 rotation,拍摄素材重编码竖屏)
        rotationProbe: _adapter.createFfprobeExecutor(),
        rotateEngine: _adapter.createFfmpegEngine(),
      );
    }
    return FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: _adapter,
      logger: _logger,
    );
  }

  /// 录屏端口(Android = MediaProjection 原生桥;桌面 = FfmpegScreenRecorder)。
  ScreenRecorderPort createScreenRecorderPort({
    required Directory capturesDir,
    required Directory tempDir,
  }) {
    if (_isAndroid) {
      return ScreenRecorderPortImpl(
        capturesDir: capturesDir,
        tempDir: tempDir,
        adapter: _adapter,
        logger: _logger,
      );
    }
    return FfmpegScreenRecorder(
      capturesDir: capturesDir,
      tempDir: tempDir,
      adapter: _adapter,
      logger: _logger,
    );
  }
}

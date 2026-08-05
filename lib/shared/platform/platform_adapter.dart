import 'dart:io' show Directory, Platform, Process, ProcessException;

import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import 'android_media_store.dart';
import 'ffmpeg_kit_engine.dart';
import 'gallery_save_result.dart';
import 'process_engine.dart';
import 'ffprobe_executor.dart';
import 'ffprobe_kit_executor.dart';
import 'process_ffprobe_executor.dart';

/// 平台差异收敛点(docs/08-FFmpeg设计.md §8.3.8、docs/04-系统架构.md Platform 层)。
///
/// 业务层禁止写 `Platform.isXxx` 分支,一律经本适配器选型。
class PlatformAdapter {
  const PlatformAdapter();

  /// Android → ffmpeg_kit 内嵌库(首发平台,本轮不验证);
  /// 桌面(Linux/Windows)→ 系统 ffprobe 二进制。
  FfprobeExecutor createFfprobeExecutor() {
    if (Platform.isAndroid) return const FfprobeKitFfprobeExecutor();
    return const ProcessFfprobeExecutor();
  }

  /// 转码引擎选型:Android → ffmpeg_kit 内嵌库;桌面 → 系统 ffmpeg 二进制。
  FFmpegEngine createFfmpegEngine() {
    if (Platform.isAndroid) return FfmpegKitEngine();
    return const ProcessEngine();
  }

  /// 转换工作目录根:桌面用系统临时目录;Android 应用专属目录(P8 确认)。
  String get systemTempDir {
    if (Platform.isAndroid) {
      // TODO(P8): getExternalFilesDir 落地;当前返回系统临时目录占位
      return Directory.systemTemp.path;
    }
    return Directory.systemTemp.path;
  }

  /// 打开系统文件管理器(尽力实现,失败仅日志,不打断用户流程)。
  Future<void> openFolder(String path) async {
    if (Platform.isLinux) {
      try {
        await Process.start('xdg-open', [path]);
      } on ProcessException {
        // 忽略:xdg-open 缺失或失败不影响应用
      }
    } else if (Platform.isWindows) {
      try {
        await Process.start('explorer', [path]);
      } on ProcessException {
        // 忽略
      }
    }
    // Android 无"文件夹"语义:完成弹窗已路由到 openGallery(定位相册条目)
  }

  /// 保存文件到系统相册(Android 10+ MediaStore 免权限;桌面返回 unsupported)。
  ///
  /// [displayName] 为相册内文件名(含 .gif 扩展名);saved 时携带展示路径
  /// 与 content URI(打开相册定位用),failed 时携带用户可读中文提示。
  Future<GallerySaveResult> saveToGallery(
    String sourcePath, {
    String? displayName,
  }) {
    if (Platform.isAndroid) {
      return const AndroidMediaStoreSaver().saveToGallery(
        sourcePath,
        displayName: displayName,
      );
    }
    return Future.value(const GallerySaveResult.unsupported());
  }

  /// 打开系统相册([uri] 非空时定位到具体条目;桌面 no-op)。
  Future<void> openGallery({String? uri}) {
    if (Platform.isAndroid) {
      return const AndroidMediaStoreSaver().openGallery(uri: uri);
    }
    return Future.value();
  }

  /// 系统分享面板发送文件(Android FileProvider;桌面 no-op)。
  Future<void> shareFile(String path) {
    if (Platform.isAndroid) {
      return const AndroidMediaStoreSaver().shareFile(path);
    }
    return Future.value();
  }
}

import 'dart:io';

import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 采集产物落位器(拍摄/录屏共用;docs/20 阶段 A、阶段 B 决策 3)。
///
/// 纯 Dart 可单测核心:私有 tmp → 素材目录持久副本(rename,失败回退
/// copy+删 tmp)→ 存相册展示副本(saveVideo)→ CaptureResult。
/// 素材目录副本供 ffprobe/转换/历史重转直接使用(ffmpeg-kit 无法解析
/// 相册 content URI);存相册失败不阻塞(failed 提示,副本保留)。
class CaptureCommitter {
  CaptureCommitter({required this.adapter, required this.capturesDir});

  final PlatformAdapter adapter;

  /// 素材落位目录(Android `<docsDir>/chameleon_gif/captures`;桌面 capturesDir)。
  final Directory capturesDir;

  /// 落位 [tmpPath] 到素材目录并返回采集结果。
  ///
  /// [fileName] 为素材命名(`capture_<ts>_<seq>.mp4`,见 capture_paths);
  /// 相册展示副本仅 Android 生效(桌面 unsupported 无操作)。
  Future<CaptureResult> commit({
    required String tmpPath,
    required String fileName,
    required int durationMs,
  }) async {
    capturesDir.createSync(recursive: true);
    final dest = File('${capturesDir.path}/$fileName');
    final tmp = File(tmpPath);
    if (tmp.existsSync()) {
      await _move(tmp, dest);
    }
    // 存相册(展示副本);失败不阻塞采集完成(副本保留供手动处理)
    final gallery = await adapter.saveVideo(dest.path, displayName: fileName);
    return CaptureResult(
      finalPath: dest.path,
      durationMs: durationMs,
      galleryStatus: gallery.status,
      galleryUri: gallery.uri,
    );
  }

  /// 移动优先,失败回退复制 + 删除源(tmp 与素材目录跨存储时 rename 抛错)。
  Future<void> _move(File tmp, File dest) async {
    try {
      await tmp.rename(dest.path);
    } on FileSystemException {
      await tmp.copy(dest.path);
      await tmp.delete();
    }
  }

  /// 取消/失败路径清理私有 tmp(幂等,不存在静默)。
  Future<void> discardTmp(String tmpPath) async {
    final tmp = File(tmpPath);
    if (await tmp.exists()) {
      try {
        await tmp.delete();
      } on FileSystemException {
        // 忽略:清理尽力语义
      }
    }
  }
}

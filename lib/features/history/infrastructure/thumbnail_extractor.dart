import 'dart:io';
import 'dart:typed_data';

import '../../../core/logger/app_logger.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';

/// 历史缩略图提取器(P5 基础版):ffmpeg 首帧 → PNG → 内存字节。
///
/// 复用 [FFmpegEngine] 端口(桌面 ProcessEngine / Android FfmpegKitEngine 均
/// 兼容,引擎选型收敛);失败(缺二进制/非零退出/无输出)→ null,UI 降级图标。
/// 会话级内存缓存(≤64 条,按 videoPath 键,避免滚动重建重复起进程);
/// 磁盘缓存与调优属 P7。
class ThumbnailExtractor {
  ThumbnailExtractor({
    required FFmpegEngine engine,
    required String cacheDir,
    required AppLogger logger,
  }) : _engine = engine,
       _cacheDir = cacheDir,
       _logger = logger;

  final FFmpegEngine _engine;
  final String _cacheDir;
  final AppLogger _logger;

  static const _maxCache = 64;
  final Map<String, Future<Uint8List?>> _cache = {};

  /// 提取首帧缩略图(幂等:并发/重复调用共享同一 Future;失败 → null)。
  Future<Uint8List?> extract(String videoPath) {
    final future = _cache.putIfAbsent(videoPath, () => _extract(videoPath));
    // 缓存上限:超限移除最旧键(近似 FIFO,防滚动重建内存膨胀)
    while (_cache.length > _maxCache) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  Future<Uint8List?> _extract(String videoPath) async {
    try {
      final dir = Directory(_cacheDir);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final pngPath = '$_cacheDir/thumb_${videoPath.hashCode}.png';
      final result = await _engine.convert(
        ConvertRequest(
          command: [
            '-ss',
            '0',
            '-i',
            videoPath,
            '-frames:v',
            '1',
            '-y',
            pngPath,
          ],
          workDir: _cacheDir,
          tempFiles: [],
        ),
      );
      final file = File(pngPath);
      if (result.exitCode != 0 || !file.existsSync()) {
        return null;
      }
      return await file.readAsBytes();
    } on Object catch (e, st) {
      _logger.w('缩略图提取失败: $videoPath', error: e, stackTrace: st);
      return null;
    }
  }
}

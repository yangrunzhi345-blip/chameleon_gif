import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/logger/app_logger.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';

/// 历史缩略图提取器(P7 磁盘缓存版):ffmpeg 首帧 → PNG → 磁盘 + 内存双层缓存。
///
/// 复用 [FFmpegEngine] 端口(桌面 ProcessEngine / Android FfmpegKitEngine 均
/// 兼容,引擎选型收敛);失败(缺二进制/非零退出/无输出)→ null,UI 降级图标。
/// 缓存结构:
/// - **内存**:≤64 条 FIFO(Map 键 videoPath,滚动重建防重复起进程);
/// - **磁盘**:`$cacheDir/thumb_<len>_<b64>.png`,跨会话复用(base64Url 稳定
///   键,不引入 crypto 依赖);源文件 mtime 新于 png 时重抽;读盘失败删疑似
///   损坏 png 重抽一次;目录超 256 张按 mtime 惰性清理(首次使用 + 写盘后
///   防御性 >384 触发)。
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

  /// 磁盘缓存上限(按 mtime 惰性清理,超过才删)。
  static const _maxDiskFiles = 256;

  /// 写盘后防御性清理阈值(单次滚动写盘激增保护)。
  static const _diskCleanupThreshold = 384;

  final Map<String, Future<Uint8List?>> _cache = {};
  bool _diskCleaned = false;

  /// 提取首帧缩略图(幂等:并发/重复调用共享同一 Future;失败 → null)。
  Future<Uint8List?> extract(String videoPath) {
    final future = _cache.putIfAbsent(videoPath, () => _resolve(videoPath));
    // 缓存上限:超限移除最旧键(近似 FIFO,防滚动重建内存膨胀)
    while (_cache.length > _maxCache) {
      _cache.remove(_cache.keys.first);
    }
    return future;
  }

  /// 磁盘命中优先,未命中(或无盘文件)才起抽帧进程。
  Future<Uint8List?> _resolve(String videoPath) async {
    final pngPath = _pngPathFor(videoPath);
    final cached = await _tryLoadDisk(pngPath, videoPath);
    if (cached != null) {
      return cached;
    }
    return _extract(videoPath, pngPath);
  }

  /// 磁盘读取:png 存在且源文件未更新 → 字节;否则 null(回落抽帧)。
  ///
  /// 源文件不存在时仍用磁盘缓存(历史记录中源已删也能显示缩略图);
  /// 读盘/stat 异常视为疑似损坏,删除 png 后回落重抽。
  Future<Uint8List?> _tryLoadDisk(String pngPath, String videoPath) async {
    final png = File(pngPath);
    if (!png.existsSync()) {
      return null;
    }
    try {
      final src = File(videoPath);
      if (src.existsSync() &&
          src.statSync().modified.isAfter(png.statSync().modified)) {
        return null; // 源文件已更新 → 重新抽帧
      }
      return await png.readAsBytes();
    } on Object catch (e, st) {
      _logger.w('缩略图磁盘读取失败,删除后重抽: $videoPath', error: e, stackTrace: st);
      try {
        png.deleteSync();
      } on Object {
        // 删除失败不阻塞,回落抽帧自行覆盖
      }
      return null;
    }
  }

  Future<Uint8List?> _extract(String videoPath, String pngPath) async {
    try {
      // 首次抽帧前惰性磁盘清扫(代价有界:仅超上限时删)
      if (!_diskCleaned) {
        _cleanupDiskTo(_maxDiskFiles);
        _diskCleaned = true;
      }
      final dir = Directory(_cacheDir);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
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
      final bytes = await file.readAsBytes();
      // 写盘后防御性清理:滚动写盘激增时不至于无限膨胀
      _cleanupDiskIfNeeded();
      return bytes;
    } on Object catch (e, st) {
      _logger.w('缩略图提取失败: $videoPath', error: e, stackTrace: st);
      return null;
    }
  }

  /// 磁盘文件名:base64Url(utf8(videoPath)) 去填充,前缀长度、截 100 字符。
  ///
  /// 稳定跨进程(与 hashCode 不同,会话间可命中);不引入 crypto 依赖
  /// (版本锁定表约束)。极端碰撞(前 100 字符 base64 相同的路径)最坏
  /// 显示错误缩略图,纯展示层可接受。
  String _pngPathFor(String videoPath) {
    final encoded = base64Url
        .encode(utf8.encode(videoPath))
        .replaceAll('=', '');
    final trimmed = encoded.length > 100 ? encoded.substring(0, 100) : encoded;
    return '$_cacheDir/thumb_${videoPath.length}_$trimmed.png';
  }

  /// 按 mtime 升序删除至 [limit] 张(最旧先删,LRU 语义)。
  void _cleanupDiskTo(int limit) {
    final files = _listPngs();
    if (files.length <= limit) {
      return;
    }
    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    for (final f in files.take(files.length - limit)) {
      try {
        f.deleteSync();
      } on Object {
        // 单文件删除失败不阻塞整体清理
      }
    }
  }

  void _cleanupDiskIfNeeded() {
    if (_listPngs().length > _diskCleanupThreshold) {
      _cleanupDiskTo(_maxDiskFiles);
    }
  }

  List<File> _listPngs() {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) {
      return [];
    }
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList();
  }
}

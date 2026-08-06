import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/repository_interfaces/file_pick_port.dart';
import '../../../domain/repository_interfaces/image_probe_port.dart';
import '../../../domain/repository_interfaces/parse_video_port.dart';

/// 导入用例(M01 Import 对外能力,docs/06-模块设计.md §6.2 M01)。
///
/// 功能层纯 Dart:
/// - [execute]:路径 → [VideoInfo](解析委托 [ParseVideoPort]);
///   [FilePickException] 家族透传(已带 errorCode + 中文 userMessage),
///   未知异常包装为通用解析失败,避免 UI 层直面技术栈。
/// - pick*:文件选择收敛进用例(UI 不再直调 [FilePickPort] 端口);
///   取消/空返回 null,后续处理(追加/导航)仍是调用方职责。
/// - [probeImageSize]:图片尺寸探测,异常归一为 null(不抛给 UI)。
class ImportVideoUseCase {
  ImportVideoUseCase({
    required ParseVideoPort parseVideoPort,
    required AppLogger logger,
    FilePickPort? filePickPort,
    ImageProbePort? imageProbePort,
  }) : _parseVideoPort = parseVideoPort,
       _logger = logger,
       _filePickPort = filePickPort,
       _imageProbePort = imageProbePort;

  final ParseVideoPort _parseVideoPort;
  final AppLogger _logger;
  final FilePickPort? _filePickPort;
  final ImageProbePort? _imageProbePort;

  Future<VideoInfo> execute(String path) async {
    _logger.i('解析视频元数据: $path');
    try {
      return await _parseVideoPort.parse(path);
    } on FilePickException {
      rethrow;
    } catch (e, st) {
      _logger.e('视频解析发生未预期异常', error: e, stackTrace: st);
      throw FilePickException.parseUnknown(cause: e);
    }
  }

  /// 选择单个视频文件(取消返回 null)。
  Future<String?> pickVideoFile() async => _filePickPort?.pickMp4();

  /// 选择多个视频文件(取消/空返回 null)。
  Future<List<String>?> pickVideoFiles() async => _filePickPort?.pickMp4s();

  /// 选择多张图片(取消/空返回 null)。
  Future<List<String>?> pickImages() async => _filePickPort?.pickImages();

  /// 探测图片尺寸;失败归一为 null(调用方按"未知"处理,不直面技术栈)。
  Future<({int width, int height})?> probeImageSize(String path) async {
    final probe = _imageProbePort;
    if (probe == null) return null;
    try {
      return await probe.probe(path);
    } catch (e, st) {
      _logger.w('图片尺寸探测失败: $path', error: e, stackTrace: st);
      return null;
    }
  }
}

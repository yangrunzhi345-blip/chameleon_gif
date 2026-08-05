import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../domain/repository_interfaces/parse_video_port.dart';

/// 导入视频解析用例(输入路径 → [VideoInfo]),M01 Import 对外能力之一,
/// 见 docs/06-模块设计.md §6.2 M01。
///
/// 功能层纯 Dart:解析委托 [ParseVideoPort](ffprobe 实现注入),
/// [FilePickException] 家族透传(已带 errorCode + 中文 userMessage),
/// 未知异常包装为通用解析失败,避免 UI 层直面技术栈。
class ImportVideoUseCase {
  ImportVideoUseCase({
    required ParseVideoPort parseVideoPort,
    required AppLogger logger,
  }) : _parseVideoPort = parseVideoPort,
       _logger = logger;

  final ParseVideoPort _parseVideoPort;
  final AppLogger _logger;

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
}

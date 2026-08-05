import '../../core/logger/app_logger.dart';
import '../../domain/entities/video_info.dart';
import '../../features/import/application/import_video_use_case.dart';

/// 采集自动导入用例(拍摄/录屏共用,docs/20 阶段 A-WP2)。
///
/// 素材路径 → [ImportVideoUseCase](ParseVideoPort + 错误包装)→ 回调跳转
/// 预览工作台;纯 Dart(不触 Riverpod/Flutter),导航经 [onImported] 回调
/// 由 provider 接线(仿 BatchImportUseCase.submit 模式)。
class CaptureImportUseCase {
  CaptureImportUseCase({
    required this.importVideoUseCase,
    required this.onImported,
    required this.logger,
  });

  final ImportVideoUseCase importVideoUseCase;

  /// 导入成功后的衔接动作(provider 装配为 push `/preview`)。
  final Future<void> Function(VideoInfo video) onImported;

  final AppLogger logger;

  /// 解析采集素材并触发跳转;返回解析后的 [VideoInfo]。
  ///
  /// [FilePickException] 家族(源缺失/损坏等)透传,由 UI 展示中文文案;
  /// 未知异常由 [ImportVideoUseCase] 包装为 parseUnknown。
  Future<VideoInfo> execute(String path) async {
    logger.i('自动导入采集素材: $path');
    final video = await importVideoUseCase.execute(path);
    await onImported(video);
    return video;
  }
}

import '../../core/logger/app_logger.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../features/import/application/import_video_use_case.dart';

/// 批量导入结果。
class BatchImportResult {
  const BatchImportResult({required this.enqueued, required this.failed});

  /// 成功入队数。
  final int enqueued;

  /// 解析失败被跳过的文件数(失败隔离)。
  final int failed;
}

/// 批量导入编排用例(P6-WP1,app 层跨模块组合)。
///
/// 跨模块组合(app 层,app 可依赖 features;features 互不依赖,见
/// docs/05 §5.2):逐文件解析 → 以调用方装配的 [setting] 入队,单文件
/// 失败跳过其余继续(完成标准"单任务失败不影响队列")。
/// 参数装配职责在 [BatchImportController.init](默认参数/原图等比),
/// 本用例退化为纯编排。
/// 纯 Dart(不触 Riverpod/Flutter),依赖经构造注入便于单测。
class BatchImportUseCase {
  BatchImportUseCase({
    required this.importVideoUseCase,
    required this.submit,
    required this.logger,
  });

  final ImportVideoUseCase importVideoUseCase;

  /// 入队接线(由 provider 装配到 TaskQueueController.submit)。
  final Future<int> Function(
    GifSetting setting,
    VideoInfo video, {
    String? outputDir,
  })
  submit;

  final AppLogger logger;

  /// 批量导入:[setting] 的 end 留 null → 入队时由 TaskManager 装配
  /// 视频时长(全长);[outputDir] 空串 → 系统临时目录。逐文件入队。
  Future<BatchImportResult> execute(
    List<String> paths, {
    required GifSetting setting,
    String? outputDir,
  }) async {
    final effective = setting.copyWith(end: null);
    final dir = (outputDir == null || outputDir.isEmpty) ? null : outputDir;
    var enqueued = 0;
    var failed = 0;
    for (final path in paths) {
      try {
        final video = await importVideoUseCase.execute(path);
        await submit(effective, video, outputDir: dir);
        enqueued++;
      } on Object catch (e, st) {
        // 失败隔离:单文件解析失败跳过,其余继续
        failed++;
        logger.e('批量导入跳过: $path', error: e, stackTrace: st);
      }
    }
    return BatchImportResult(enqueued: enqueued, failed: failed);
  }
}

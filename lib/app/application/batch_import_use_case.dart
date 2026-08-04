import '../../core/logger/app_logger.dart';
import '../../domain/entities/video_info.dart';
import '../../domain/repository_interfaces/settings_repository.dart';
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

/// 批量导入编排用例(P6-WP1)。
///
/// 跨模块组合(app 层,app 可依赖 features;features 互不依赖,见
/// docs/05 §5.2):逐文件解析 → 以默认参数直接入队,单文件失败跳过其余
/// 继续(完成标准"单任务失败不影响队列")。
/// 参数装配:已保存默认参数为基底,end 留 null(全长),**宽高恒为 0
/// (原图等比)**——批量导入各视频源分辨率不同,忽略用户保存的固定宽高,
/// 其余默认参数(fps/循环等)继续生效。
/// 纯 Dart(不触 Riverpod/Flutter),依赖经构造注入便于单测。
class BatchImportUseCase {
  BatchImportUseCase({
    required this.importVideoUseCase,
    required this.submit,
    required this.settingsRepository,
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

  final SettingsRepository settingsRepository;
  final AppLogger logger;

  /// 批量导入:默认参数 + 全长裁剪 + 默认导出目录,逐文件入队。
  Future<BatchImportResult> execute(List<String> paths) async {
    // end 留 null:入队时由 TaskManager 装配视频时长(全长);
    // 宽高强制 0:批量导入默认为原图等比,忽略已保存的固定宽高
    final base = (settingsRepository.defaultGifSetting ?? const GifSetting())
        .copyWith(end: null, width: 0, height: 0);
    final outputDir = settingsRepository.defaultExportDir;
    var enqueued = 0;
    var failed = 0;
    for (final path in paths) {
      try {
        final video = await importVideoUseCase.execute(path);
        await submit(
          base,
          video,
          outputDir: outputDir.isEmpty ? null : outputDir,
        );
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

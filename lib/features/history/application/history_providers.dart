import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/export_history.dart';
import '../../../shared/providers/core_providers.dart';
import '../infrastructure/thumbnail_extractor.dart';
import 'history_controller.dart';

/// 历史列表(§9.2 层次一,常驻;初始异步加载,completed 自动刷新)。
final historyControllerProvider =
    NotifierProvider<HistoryController, AsyncValue<List<ExportHistory>>>(
      HistoryController.new,
    );

/// 缩略图提取器(基础设施;缓存目录取平台临时目录,测试 override 注入 Fake)。
final thumbnailExtractorProvider = Provider<ThumbnailExtractor>((ref) {
  final adapter = ref.watch(platformAdapterProvider);
  return ThumbnailExtractor(
    engine: ref.watch(ffmpegEngineProvider),
    cacheDir: '${adapter.systemTempDir}/gifforge_thumbs',
    logger: ref.watch(appLoggerProvider),
  );
});

/// 单条历史缩略图(路径 → 字节;null = 降级图标)。
final historyThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, videoPath) =>
          ref.watch(thumbnailExtractorProvider).extract(videoPath),
    );

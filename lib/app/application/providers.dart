import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/app_theme_mode.dart';
import '../../features/import/application/import_providers.dart';
import '../../features/task_queue/application/task_queue_providers.dart';
import '../../shared/providers/core_providers.dart';
import 'batch_import_use_case.dart';
import 'theme_controller.dart';

/// 应用级 Provider(组合根)。
///
/// 共享基础设施 provider(isar/prefs/logger/仓储/平台端口)归
/// `lib/shared/providers/core_providers.dart`(features 依赖方向合法);
/// 依赖功能模块实现的装配(ffprobe 端口/FFmpeg 服务)由 `main()` 注入。
/// 本文件只保留纯应用态。
final themeModeProvider = NotifierProvider<ThemeController, AppThemeMode>(
  ThemeController.new,
);

/// 批量导入编排(P6-WP1;跨模块组合收敛于 app 层,features 互不依赖)。
final batchImportUseCaseProvider = Provider<BatchImportUseCase>((ref) {
  return BatchImportUseCase(
    importVideoUseCase: ref.watch(importVideoUseCaseProvider),
    submit: (setting, video, {String? outputDir}) => ref
        .read(taskQueueControllerProvider.notifier)
        .submit(setting, video, outputDir: outputDir),
    logger: ref.watch(appLoggerProvider),
  );
});

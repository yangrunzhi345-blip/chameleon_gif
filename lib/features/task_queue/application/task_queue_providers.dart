import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/application/providers.dart';
import '../../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../../shared/platform/platform_adapter.dart';
import '../../converter/application/ffmpeg_service_engine.dart';
import 'task_manager.dart';
import 'task_queue_controller.dart';
import 'task_queue_state.dart';

/// FFmpeg 转码服务(编排层,经 PlatformAdapter 选型引擎)。
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  final adapter = const PlatformAdapter();
  return FfmpegServiceEngine(
    engine: adapter.createFfmpegEngine(),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 任务调度器(常驻,单并发槽)。
final taskManagerProvider = Provider<TaskManager>((ref) {
  return TaskManager(
    taskRepository: ref.watch(taskRepositoryProvider),
    historyRepository: ref.watch(historyRepositoryProvider),
    ffmpegService: ref.watch(ffmpegServiceProvider),
    platformAdapter: const PlatformAdapter(),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 任务队列状态(docs/09 §9.2 层次一,常驻)。
final taskQueueControllerProvider =
    NotifierProvider<TaskQueueController, TaskQueueState>(
      TaskQueueController.new,
    );

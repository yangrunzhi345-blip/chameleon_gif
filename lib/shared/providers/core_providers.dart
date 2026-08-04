import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../domain/repository_interfaces/history_repository.dart';
import '../../domain/repository_interfaces/parse_video_port.dart';
import '../../domain/repository_interfaces/settings_repository.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../platform/platform_adapter.dart';
import '../repositories/in_memory_history_repository.dart';
import '../repositories/in_memory_task_repository.dart';
import '../repositories/settings_repository_impl.dart';

/// 共享 Provider 注册表(docs/09-状态管理.md §9.2 层次一)。
///
/// 只定义**接口类型**与可自给自足的默认实现(内存仓储/平台适配器等);
/// 依赖功能模块实现(ffprobe 端口/FFmpeg 服务)的 provider 默认抛
/// UnimplementedError,由组合根 `main()` 经 ProviderScope overrides 注入
/// —— 保持 shared → features 依赖方向,features 亦不反向依赖 app。
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final platformAdapterProvider = Provider<PlatformAdapter>(
  (ref) => const PlatformAdapter(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SharedPrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

/// 任务仓储(P3 内存过渡;P5-WP1 替换为 Isar 仓储,见 docs/12)。
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return InMemoryTaskRepository();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return InMemoryHistoryRepository();
});

/// 视频元数据解析端口(接口型;实现由 main() 注入,见 main.dart)。
final parseVideoPortProvider = Provider<ParseVideoPort>((ref) {
  throw UnimplementedError('由 main() 注入');
});

/// FFmpeg 引擎(接口型;实现由 main() 注入,经 PlatformAdapter 选型)。
final ffmpegEngineProvider = Provider<FFmpegEngine>((ref) {
  throw UnimplementedError('由 main() 注入');
});

/// FFmpeg 转码服务(接口型;实现由 main() 注入,编排引擎 + 解析器)。
final ffmpegServiceProvider = Provider<FFmpegService>((ref) {
  throw UnimplementedError('由 main() 注入');
});

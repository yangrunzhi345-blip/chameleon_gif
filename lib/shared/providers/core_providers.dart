import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/repository_interfaces/camera_port.dart';
import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../domain/repository_interfaces/history_repository.dart';
import '../../domain/repository_interfaces/parse_video_port.dart';
import '../../domain/repository_interfaces/screen_recorder_port.dart';
import '../../domain/repository_interfaces/settings_repository.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../platform/platform_adapter.dart';
import '../repositories/isar_history_repository.dart';
import '../repositories/isar_task_repository.dart';
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

/// 应用文档目录(接口型;main() 注入 getApplicationDocumentsDirectory(),
/// 三平台统一,与 Isar 数据目录同根)。
final appDocsDirProvider = Provider<Directory>((ref) {
  throw UnimplementedError('由 main() 注入');
});

/// 采集素材落位目录(docs/18 D1 素材持久可重转;阶段 B 决策 3):
/// `<docsDir>/chameleon_gif/captures`,首次访问自动创建。
/// 拍摄/录屏 finalPath 指向此处的真实文件,ffprobe/转换/历史重转直接可用。
final capturesFileDirProvider = Provider<Directory>((ref) {
  final docs = ref.watch(appDocsDirProvider);
  final dir = Directory('${docs.path}/chameleon_gif/captures');
  dir.createSync(recursive: true);
  return dir;
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SharedPrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

/// 任务仓储(Isar 持久化,P5-WP1;测试经 override 注入 InMemory 版)。
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return IsarTaskRepository(
    ref.watch(isarProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// 历史仓储(Isar 持久化,P5-WP1;测试经 override 注入 InMemory 版)。
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return IsarHistoryRepository(
    ref.watch(isarProvider),
    logger: ref.watch(appLoggerProvider),
  );
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

/// 相机拍摄端口(接口型;实现由 main() 注入,Android = CameraPortImpl)。
final cameraPortProvider = Provider<CameraPort>((ref) {
  throw UnimplementedError('由 main() 注入');
});

/// 录屏端口(接口型;实现由 main() 注入,Android = ScreenRecorderPortImpl)。
final screenRecorderPortProvider = Provider<ScreenRecorderPort>((ref) {
  throw UnimplementedError('由 main() 注入');
});

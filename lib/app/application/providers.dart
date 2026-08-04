import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';
import '../../domain/repository_interfaces/history_repository.dart';
import '../../domain/repository_interfaces/parse_video_port.dart';
import '../../domain/repository_interfaces/settings_repository.dart';
import '../../domain/repository_interfaces/task_repository.dart';
import '../../features/converter/infrastructure/ffprobe_parse_video_port.dart';
import '../../shared/platform/platform_adapter.dart';
import '../../shared/repositories/settings_repository_impl.dart';
import 'theme_controller.dart';

/// 全局 Provider(docs/09-状态管理.md §9.2 层次一)。
///
/// 运行时依赖(isar/prefs/logger)由 main() 经 ProviderScope overrides 注入;
/// 仓储接口在此绑定实现(测试经 overrides 替换为 Mock)。
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  throw UnimplementedError('由 main() 注入');
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SharedPrefsSettingsRepository(ref.watch(sharedPrefsProvider)),
);

/// 视频元数据解析端口(ffprobe 实现),见 docs/12-开发计划.md P1-WP1。
/// 惰性求值:未被 watch 时不触发任何平台调用;执行器经 PlatformAdapter 选型
/// (桌面=系统二进制,Android=ffmpeg_kit 内嵌库)。
final parseVideoPortProvider = Provider<ParseVideoPort>(
  (ref) => FfprobeParseVideoPort(
    executor: const PlatformAdapter().createFfprobeExecutor(),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// Task/History 仓储实现由 P5 落地(Isar 仓储),当前留桩,
/// 见 docs/12-开发计划.md P5-WP1。
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  throw UnimplementedError('P5 阶段落地(Isar 实现)');
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  throw UnimplementedError('P5 阶段落地(Isar 实现)');
});

/// 主题三态(持久化)
final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

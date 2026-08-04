import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/logger/app_logger.dart';
import 'features/converter/application/ffmpeg_service_engine.dart';
import 'features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'shared/platform/platform_adapter.dart';
import 'shared/providers/core_providers.dart';
import 'shared/repositories/schemas/export_history_schema.dart';
import 'shared/repositories/schemas/export_preset_schema.dart';
import 'shared/repositories/schemas/export_task_schema.dart';

/// 应用入口:初始化(日志 → Isar → MediaKit → 偏好)→ 组装 ProviderScope。
///
/// 初始化失败直接退出并打印错误(日志通道不可用时降级 console)。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger();
  logger.i('GifForge 启动中...');

  final Isar isar;
  try {
    // 数据目录:平台应用文档目录下的 gif_forge(三平台统一,见 PlatformAdapter)
    final docsDir = await getApplicationDocumentsDirectory();
    final isarDir = Directory('${docsDir.path}/gif_forge')
      ..createSync(recursive: true);
    isar = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
      ExportPresetSchemaSchema,
    ], directory: isarDir.path);
  } catch (e, st) {
    logger.f('Isar 初始化失败', error: e, stackTrace: st);
    rethrow;
  }

  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final adapter = PlatformAdapter();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(logger),
        // 组合根装配功能模块实现(shared/providers 只定义接口型 provider)
        parseVideoPortProvider.overrideWithValue(
          FfprobeParseVideoPort(
            executor: adapter.createFfprobeExecutor(),
            logger: logger,
          ),
        ),
        ffmpegEngineProvider.overrideWithValue(adapter.createFfmpegEngine()),
        ffmpegServiceProvider.overrideWithValue(
          FfmpegServiceEngine(
            engine: adapter.createFfmpegEngine(),
            logger: logger,
          ),
        ),
      ],
      child: const GifForgeApp(),
    ),
  );
}

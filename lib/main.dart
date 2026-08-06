import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/logger/app_logger.dart';
import 'core/utils/startup_tracer.dart';
import 'features/camera/infrastructure/camera_port_impl.dart';
import 'features/converter/application/ffmpeg_service_engine.dart';
import 'features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'features/screen_record/infrastructure/screen_recorder_port_impl.dart';
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
  final tracer = StartupTracer(logger);
  tracer.mark('t0 入口');
  logger.i('Chameleon Gif 启动中...');

  final Isar isar;
  // 数据目录:平台应用文档目录下的 chameleon_gif(三平台统一,见 PlatformAdapter);
  // 供 appDocsDirProvider 注入(采集素材落位根,阶段 B 共享面)
  final Directory docsDir;
  try {
    docsDir = await getApplicationDocumentsDirectory();
    tracer.mark('t1 docsDir 就绪');
    final isarDir = Directory('${docsDir.path}/chameleon_gif')
      ..createSync(recursive: true);
    isar = await Isar.open([
      ExportTaskSchemaSchema,
      ExportHistorySchemaSchema,
      ExportPresetSchemaSchema,
    ], directory: isarDir.path);
    tracer.mark('t2 Isar.open 完成');
  } catch (e, st) {
    logger.f('Isar 初始化失败', error: e, stackTrace: st);
    rethrow;
  }

  MediaKit.ensureInitialized();
  tracer.mark('t3 MediaKit 完成');
  final prefs = await SharedPreferences.getInstance();
  tracer.mark('t4 prefs 完成');
  final adapter = PlatformAdapter();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(logger),
        appDocsDirProvider.overrideWithValue(docsDir),
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
        // Android 相机拍摄(桌面亦注入:端口枚举空列表 → 页面空态)
        cameraPortProvider.overrideWithValue(
          CameraPortImpl(
            capturesDir: Directory('${docsDir.path}/chameleon_gif/captures'),
            adapter: adapter,
            logger: logger,
            // 素材竖屏化(media_kit 不应用 rotation,拍摄素材重编码竖屏)
            rotationProbe: adapter.createFfprobeExecutor(),
            rotateEngine: adapter.createFfmpegEngine(),
          ),
        ),
        // Android 录屏(自写 MediaProjection 原生桥;桌面亦注入:
        // 通道 MissingPluginException → 录制失败提示)
        screenRecorderPortProvider.overrideWithValue(
          ScreenRecorderPortImpl(
            capturesDir: Directory('${docsDir.path}/chameleon_gif/captures'),
            tempDir: Directory.systemTemp,
            adapter: adapter,
            logger: logger,
          ),
        ),
      ],
      child: const ChameleonGifApp(),
    ),
  );
  // 首帧打点 + 分段输出(P7 基线;默认关闭)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    tracer.mark('t5 首帧');
    tracer.dump();
  });
}

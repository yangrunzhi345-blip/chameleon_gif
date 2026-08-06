import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/application/capture_platform_factory.dart';
import 'app/app.dart';
import 'app/router.dart' show rootNavigatorKey;
import 'core/logger/app_logger.dart';
import 'core/utils/startup_tracer.dart';
import 'features/converter/application/ffmpeg_service_engine.dart';
import 'features/converter/infrastructure/ffprobe_parse_video_port.dart';
import 'features/screen_record/application/region_picker.dart'
    show screenRegionPickerProvider;
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
  // 窗口管理注册(桌面;录屏区域框选遮罩用)。纯 Dart 通道注册无原生副作用,
  // Wayland 下无害(遮罩分支仅在 X11/Windows 装配,见 CapturePlatformFactory)。
  if (Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
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
  // 采集端口选型工厂(Android 插件/原生桥;桌面 ffmpeg 采集,见工厂注释)
  final captureFactory = CapturePlatformFactory(
    adapter: adapter,
    logger: logger,
  );
  final capturesDir = Directory('${docsDir.path}/chameleon_gif/captures');

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
        // 相机拍摄端口(Android = camera 插件;桌面 = ffmpeg v4l2/dshow 采集)
        cameraPortProvider.overrideWithValue(
          captureFactory.createCameraPort(capturesDir: capturesDir),
        ),
        // 录屏端口(Android = MediaProjection 原生桥;桌面 = ffmpeg
        // gdigrab/x11grab/pipewire 采集)
        screenRecorderPortProvider.overrideWithValue(
          captureFactory.createScreenRecorderPort(
            capturesDir: capturesDir,
            tempDir: Directory.systemTemp,
          ),
        ),
        // 录屏区域框选器(Wayland = slurp;X11/Windows = 全屏截图遮罩拖拽)
        screenRegionPickerProvider.overrideWithValue(
          captureFactory.createRegionPicker(
            navigatorKey: rootNavigatorKey,
            tempDir: Directory.systemTemp,
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

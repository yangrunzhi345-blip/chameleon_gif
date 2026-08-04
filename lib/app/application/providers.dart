import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

/// 应用级 Provider(组合根)。
///
/// 共享基础设施 provider(isar/prefs/logger/仓储/平台端口)归
/// `lib/shared/providers/core_providers.dart`(features 依赖方向合法);
/// 依赖功能模块实现的装配(ffprobe 端口/FFmpeg 服务)由 `main()` 注入。
/// 本文件只保留纯应用态。
final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

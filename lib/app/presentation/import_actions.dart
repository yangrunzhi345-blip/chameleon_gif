import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/exceptions/file_pick_exception.dart';
import '../../features/import/application/import_providers.dart';

/// 选 MP4 → 解析 → 跳预览(首页"导入 MP4"与完成弹窗"返回单独导入mp4"
/// 共用,防逻辑漂移)。
///
/// 取消选择静默;解析失败以 SnackBar 展示用户可读中文文案。
Future<void> pickMp4AndPreview(BuildContext context, WidgetRef ref) async {
  final path = await ref.read(filePickPortProvider).pickMp4();
  if (path == null || !context.mounted) return;
  try {
    final info = await ref.read(importVideoUseCaseProvider).execute(path);
    if (!context.mounted) return;
    context.push('/preview', extra: info);
  } on FilePickException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.userMessage)));
  }
}

/// 多选图片 → 跳图片制作页(首页"图片制作 GIF"入口)。
///
/// 取消选择静默;路径列表(JSON 基础类型)经路由 extra 传递,恢复安全。
Future<void> pickImagesAndBuild(BuildContext context, WidgetRef ref) async {
  final paths = await ref.read(filePickPortProvider).pickImages();
  if (paths == null || paths.isEmpty || !context.mounted) return;
  context.push('/image-gif', extra: paths);
}

/// 打开相机拍摄页(首页"相机拍摄"入口;docs/18 §五)。
///
/// 平台态(Android 常亮 / 桌面置灰)由 home_page 控制,此处只做跳转。
void openCaptureScreen(BuildContext context, WidgetRef ref) =>
    context.push('/capture');

/// 打开屏幕录制页(首页"屏幕录制"入口;docs/19 §三)。
///
/// 平台态由 home_page 控制;区域选择在录制页内完成,入口保持单一动作。
void openRecordScreen(BuildContext context, WidgetRef ref) =>
    context.push('/record');

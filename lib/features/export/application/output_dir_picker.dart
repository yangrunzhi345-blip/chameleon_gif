import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/exceptions/file_pick_exception.dart';
import '../../../shared/providers/core_providers.dart';
import 'export_providers.dart';

/// 目录选择公共动作(export/image_gif/batch 三控制器共用,防逻辑漂移)。
///
/// 语义:初始目录 = 当前表单值 ∪ 持久化默认;成功后回填表单 + 持久化
/// 默认导出目录;FilePickException → [onError](表单级错误);用户取消
/// (null)静默。[locked] 由调用方传入(各状态类锁定语义不同;
/// batch 表单无锁定概念,传 false)。
Future<void> pickOutputDir({
  required Ref ref,
  required String? currentOutputDir,
  required bool locked,
  required void Function(String? dir) onPicked,
  required void Function(String message) onError,
}) async {
  if (locked) return;
  final initial =
      currentOutputDir ?? ref.read(settingsRepositoryProvider).defaultExportDir;
  try {
    final dir = await ref
        .read(directoryPickPortProvider)
        .pickDirectory(initialDirectory: initial.isEmpty ? null : initial);
    if (dir == null) return; // 用户取消
    onPicked(dir);
    await ref.read(settingsRepositoryProvider).setDefaultExportDir(dir);
  } on FilePickException catch (e) {
    if (locked) return;
    onError(e.userMessage);
  }
}

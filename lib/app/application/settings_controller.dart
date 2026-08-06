import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/gif_setting.dart';
import '../../shared/providers/core_providers.dart';
import 'batch_form_mixin.dart';
import 'batch_import_state.dart';

/// 设置页控制器 provider(会话级,autoDispose:进入设置页创建,离开销毁)。
/// 与控制器同文件定义,避免 providers 与 controller 循环 import。
final settingsControllerProvider =
    NotifierProvider.autoDispose<SettingsController, BatchImportFormState>(
      SettingsController.new,
    );

/// 设置页控制器(app 层,autoDispose)。
///
/// 管理"批量导入默认参数"表单:表单方法由 [BatchFormMixin] 承载,
/// 本类只保留 [init](**原样载入**持久化默认——与批量导入会话的强制
/// 原图等比/全长语义不同,设置页显示用户实际存储的默认)与 [save]
/// (写回 defaultGifSetting + defaultExportDir)。
class SettingsController extends Notifier<BatchImportFormState>
    with BatchFormMixin {
  @override
  BatchImportFormState build() => const BatchImportFormState.idle();

  /// 会话初始化:原样载入持久化默认参数(无默认则内置)。
  ///
  /// 不强制宽高 0 / end null(那是批量导入会话语义,见
  /// [BatchImportController.init]);outputDir 取默认导出目录(空 → null)。
  void init() {
    final repo = ref.read(settingsRepositoryProvider);
    final saved = repo.defaultGifSetting ?? const GifSetting();
    final outputDir = repo.defaultExportDir;
    final w = saved.width;
    final h = saved.height;
    state = state.copyWith(
      fps: saved.fps,
      width: w,
      height: h,
      loop: saved.loop,
      start: saved.start,
      end: saved.end,
      outputDir: outputDir.isEmpty ? null : outputDir,
      // 宽高全 0(原图等比)才继承倍数偏好;手动指定过宽高 → null
      scaleMultiplier: (w == 0 && h == 0) ? saved.scaleMultiplier : null,
      playbackSpeed: saved.playbackSpeed.clamp(0.25, 4),
      formError: null,
    );
  }

  /// 保存默认参数:写回 defaultGifSetting + defaultExportDir。
  Future<void> save() async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDefaultGifSetting(assembleSetting());
    await repo.setDefaultExportDir(state.outputDir ?? '');
  }
}

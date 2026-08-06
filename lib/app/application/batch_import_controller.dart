import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/gif_setting.dart';
import '../../shared/providers/core_providers.dart';
import 'batch_form_mixin.dart';
import 'batch_import_state.dart';
import 'batch_import_use_case.dart';
import 'batch_session_controller.dart';
import 'providers.dart';

/// 批量导入设置控制器 provider(会话级,autoDispose:进入设置页创建,
/// 离开销毁)。与控制器同文件定义,避免 providers 与 controller 循环
/// import(preview_controller.dart 同模式)。
final batchImportControllerProvider =
    NotifierProvider.autoDispose<BatchImportController, BatchImportFormState>(
      BatchImportController.new,
    );

/// 批量导入设置控制器(app 层跨模块组合,autoDispose,docs/09 §9.2 层次二)。
///
/// 会话语义:表单方法(update*/pickOutputDir/装配)由 [BatchFormMixin]
/// 承载;本类只保留 [init](从持久化默认参数初始化,**宽高强制 0 原图等比、
/// end 强制 null 全长**,其余默认保留)与 [start](校验后经
/// [BatchImportUseCase] 逐文件解析入队,失败隔离在用例内)。
/// 与 [SettingsController] 的区别:设置页原样载入持久化默认,批量会话
/// 强制原图等比/全长。
class BatchImportController extends Notifier<BatchImportFormState>
    with BatchFormMixin {
  bool _submitting = false;

  @override
  BatchImportFormState build() => const BatchImportFormState.idle();

  /// 会话初始化:应用持久化默认参数,宽高强制 0(原图等比)、end 留 null(全长)。
  ///
  /// fps/loop/start 继承已保存默认;outputDir 取默认导出目录(空 → null)。
  void init() {
    final repo = ref.read(settingsRepositoryProvider);
    final saved = repo.defaultGifSetting;
    final base = (saved ?? const GifSetting()).copyWith(
      width: 0,
      height: 0,
      end: null,
    );
    final outputDir = repo.defaultExportDir;
    state = state.copyWith(
      fps: base.fps.clamp(1, 60),
      width: 0,
      height: 0,
      loop: base.loop.clamp(0, 100),
      start: base.start.isNegative ? Duration.zero : base.start,
      end: null,
      outputDir: outputDir.isEmpty ? null : outputDir,
      // 宽高强制 0(原图等比)的同时继承倍数偏好 → 入队时按各视频
      // 自身尺寸 × 倍数展开(需求 4 接线点)
      scaleMultiplier: base.scaleMultiplier,
      playbackSpeed: base.playbackSpeed.clamp(0.25, 4),
      formError: null,
    );
  }

  /// 校验并启动批量转换(逐文件解析入队,用例内失败隔离)。
  ///
  /// `end != null && start >= end` → 拒绝(formError + 返回空结果,不调用
  /// 用例);重入守卫防连点(第一轮未完成时忽略后续调用)。
  Future<BatchImportResult> start(List<String> paths) async {
    if (_submitting) {
      return const BatchImportResult(enqueued: 0, failed: 0);
    }
    _submitting = true;
    try {
      final end = state.end;
      if (end != null && state.start >= end) {
        state = state.copyWith(formError: '起点不能晚于或等于终点');
        return const BatchImportResult(enqueued: 0, failed: 0);
      }
      final result = await ref
          .read(batchImportUseCaseProvider)
          .execute(
            paths,
            setting: assembleSetting(),
            outputDir: state.outputDir,
          );
      // 入队成功即登记批次会话(完成后弹窗的判定源)
      if (result.enqueued > 0) {
        ref.read(batchSessionProvider.notifier).begin(result.taskIds);
      }
      return result;
    } finally {
      _submitting = false;
    }
  }
}

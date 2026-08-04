import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_math.dart';
import '../../domain/exceptions/file_pick_exception.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../features/export/application/export_providers.dart'
    show directoryPickPortProvider;
import '../../shared/providers/core_providers.dart';
import 'batch_import_state.dart';

/// 批量参数表单动作集(组件与控制器之间的最小契约)。
///
/// [BatchParameterForm](presentation/batch_parameter_form.dart) 经此接口
/// 转发事件,批量导入会话控制器与设置页控制器都实现它;接线一行:
/// `BatchParameterForm(actions: ref.read(xxxControllerProvider.notifier))`。
/// `updateOutputDir` 不进接口(表单只经"选择目录"按钮调 [pickOutputDir],
/// 内部已更新目录)。
abstract interface class BatchFormActions {
  /// 帧率(钳制 1–60)。
  void updateFps(double fps);

  /// 宽度(钳制 0–4096,0 = 原图等比)。
  void updateWidth(int width);

  /// 高度(钳制 0–4096,0 = 原图等比)。
  void updateHeight(int height);

  /// 循环次数(钳制 0–100,0 = 无限)。
  void updateLoop(int loop);

  /// 起点(负值钳 0 + 与终点自动交换)。
  void updateStart(Duration start);

  /// 终点(null = 到视频结尾;负值钳 0 + 与起点自动交换)。
  void updateEnd(Duration? end);

  /// 打开系统目录选择器;成功后回填表单并持久化为默认导出目录。
  Future<void> pickOutputDir();

  /// 设置表单级错误(时间格式非法等;非空时禁用提交按钮)。
  void updateFormError(String message);

  /// 清除表单级错误(输入修正后)。
  void clearFormError();
}

/// 批量参数表单公共实现(功能层纯 Dart,无 Flutter 依赖)。
///
/// 承载 [BatchImportController] 与 [SettingsController] 共用的表单逻辑
/// (update* 钳制 + 起止自动交换、目录选择、表单装配),行为与迁移前
/// 逐字一致(batch_import_controller_test 为行为基线)。
///
/// 与 [ExportController](features/export) 的表单方法同构但无 locked/
/// timeline 联动、无视频时长上钳制(多文件/默认参数无单一时长,超时长
/// 由 ffmpeg -to 自然截断)——差异保留在各自控制器,不进 mixin。
mixin BatchFormMixin on Notifier<BatchImportFormState>
    implements BatchFormActions {
  @override
  void updateFps(double fps) {
    state = state.copyWith(fps: fps.clamp(1, 60), formError: null);
  }

  @override
  void updateWidth(int width) {
    state = state.copyWith(width: width.clamp(0, 4096), formError: null);
  }

  @override
  void updateHeight(int height) {
    state = state.copyWith(height: height.clamp(0, 4096), formError: null);
  }

  @override
  void updateLoop(int loop) {
    state = state.copyWith(loop: loop.clamp(0, 100), formError: null);
  }

  @override
  void updateStart(Duration start) {
    final (s, e) = _normalized(start, state.end);
    state = state.copyWith(start: s, end: e, formError: null);
  }

  @override
  void updateEnd(Duration? end) {
    if (end == null) {
      state = state.copyWith(end: null, formError: null);
      return;
    }
    final (s, e) = _normalized(state.start, end);
    state = state.copyWith(start: s, end: e, formError: null);
  }

  /// 设置导出目录(空串 → null = 系统临时目录)。
  void updateOutputDir(String? dir) {
    state = state.copyWith(
      outputDir: (dir == null || dir.isEmpty) ? null : dir,
      formError: null,
    );
  }

  @override
  Future<void> pickOutputDir() async {
    final initial =
        state.outputDir ??
        ref.read(settingsRepositoryProvider).defaultExportDir;
    try {
      final dir = await ref
          .read(directoryPickPortProvider)
          .pickDirectory(initialDirectory: initial.isEmpty ? null : initial);
      if (dir == null) return; // 用户取消
      updateOutputDir(dir);
      await ref.read(settingsRepositoryProvider).setDefaultExportDir(dir);
    } on FilePickException catch (e) {
      state = state.copyWith(formError: e.userMessage);
    }
  }

  @override
  void updateFormError(String message) {
    state = state.copyWith(formError: message);
  }

  @override
  void clearFormError() {
    state = state.copyWith(formError: null);
  }

  /// 表单 → GifSetting(end 保留 null,由 TaskManager 装配视频时长)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    width: state.width,
    height: state.height,
    loop: state.loop,
    start: state.start,
    end: state.end,
  );

  /// 起止归一化:负值钳 0,end 为 null 保持 null;均非空时自动交换。
  (Duration, Duration?) _normalized(Duration start, Duration? end) {
    final s = start.isNegative ? Duration.zero : start;
    if (end == null) return (s, null);
    final e = end.isNegative ? Duration.zero : end;
    return normalizeRange(s, e);
  }
}

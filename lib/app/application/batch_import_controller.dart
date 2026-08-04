import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_math.dart';
import '../../domain/exceptions/file_pick_exception.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../features/export/application/export_providers.dart'
    show directoryPickPortProvider;
import '../../shared/providers/core_providers.dart';
import 'batch_import_state.dart';
import 'batch_import_use_case.dart';
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
/// 表单状态与校验(纯逻辑,无预览/无时间轴联动):[init] 从持久化默认
/// 参数初始化(**宽高强制 0 原图等比、end 强制 null 全长**,其余默认保留),
/// update* 钳制 + 起止自动交换;[start] 校验后经 [BatchImportUseCase]
/// 逐文件解析入队(失败隔离在用例内)。与 [ExportController] 的区别:
/// 无 locked/lifecycle、无 timeline 回写、无视频时长上钳制(多文件
/// 无单一时长,超时长由 ffmpeg -to 自然截断)。
class BatchImportController extends Notifier<BatchImportFormState> {
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
      formError: null,
    );
  }

  // ---- 表单更新(均清空 formError) ----

  /// 帧率(钳制 1–60)。
  void updateFps(double fps) {
    state = state.copyWith(fps: fps.clamp(1, 60), formError: null);
  }

  /// 宽度(钳制 0–4096,0 = 原图等比)。
  void updateWidth(int width) {
    state = state.copyWith(width: width.clamp(0, 4096), formError: null);
  }

  /// 高度(钳制 0–4096,0 = 原图等比)。
  void updateHeight(int height) {
    state = state.copyWith(height: height.clamp(0, 4096), formError: null);
  }

  /// 循环次数(钳制 0–100,0 = 无限)。
  void updateLoop(int loop) {
    state = state.copyWith(loop: loop.clamp(0, 100), formError: null);
  }

  /// 起点(负值钳 0 + 与终点自动交换)。
  void updateStart(Duration start) {
    final (s, e) = _normalized(start, state.end);
    state = state.copyWith(start: s, end: e, formError: null);
  }

  /// 终点(null = 到视频结尾;负值钳 0 + 与起点自动交换)。
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

  /// 打开系统目录选择器;成功后回填表单并持久化为默认导出目录。
  ///
  /// 取消(null)静默;选择失败 → formError 中文提示。
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

  /// 设置表单级错误(时间格式非法等;非空时禁用开始按钮)。
  void updateFormError(String message) {
    state = state.copyWith(formError: message);
  }

  /// 清除表单级错误(输入修正后)。
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
      return await ref
          .read(batchImportUseCaseProvider)
          .execute(
            paths,
            setting: assembleSetting(),
            outputDir: state.outputDir,
          );
    } finally {
      _submitting = false;
    }
  }

  /// 起止归一化:负值钳 0,end 为 null 保持 null;均非空时自动交换。
  (Duration, Duration?) _normalized(Duration start, Duration? end) {
    final s = start.isNegative ? Duration.zero : start;
    if (end == null) return (s, null);
    final e = end.isNegative ? Duration.zero : end;
    return normalizeRange(s, e);
  }
}

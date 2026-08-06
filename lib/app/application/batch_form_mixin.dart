import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_format.dart';
import '../../core/utils/duration_math.dart';
import '../../domain/value_objects/gif_setting.dart';
// 别名:顶层函数与混入的抽象成员同名,须经别名调用
import '../../features/export/application/output_dir_picker.dart'
    as output_dir_picker;
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

  /// 等比缩放倍数(源尺寸未知:仅存偏好,宽高重置 0,入队时按各文件
  /// 自身尺寸展开)。
  void updateScaleMultiplier(double multiplier);

  /// 循环次数(钳制 0–100,0 = 无限)。
  void updateLoop(int loop);

  /// 播放速度(钳制 0.25–4:<1 慢放,>1 加速;命令侧 setpts)。
  void updatePlaybackSpeed(double speed);

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

  // ---- 文本输入解析+校验(UI 文本 → 状态,短路语义) ----
  // 与 export/image_gif 的 try* 系列同构:解析/范围校验/错误文案下沉
  // 控制器,UI 只转发;任一失败设 formError 返回 false,调用方逐字段
  // 短路调用(后项成功不清前项错误)。

  /// 循环次数文本:非数字 → formError 返回 false;成功应用返回 true。
  bool tryUpdateLoopText(String text);

  /// 开始时间文本:格式非法 → formError 返回 false;成功应用返回 true。
  bool tryUpdateStartText(String text);

  /// 结束时间文本:留空 → null(到结尾);格式非法 → formError 返回 false。
  bool tryUpdateEndText(String text);

  /// 自定义宽度文本(1–4096)。
  bool tryUpdateCustomWidth(String text);

  /// 自定义高度文本(1–4096)。
  bool tryUpdateCustomHeight(String text);

  /// 自定义缩放倍数文本(0.1–4)。
  bool tryUpdateCustomScaleMultiplier(String text);
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
    final w = width.clamp(0, 4096);
    // 手动指定宽高 → 倍数回显"自定义"(null);恢复 (0,0) 原图等比 →
    // 1.0(不缩放;选倍数设置的偏好已被手动操作覆盖,不再回显)
    state = state.copyWith(
      width: w,
      scaleMultiplier: (w == 0 && state.height == 0) ? 1.0 : null,
      formError: null,
    );
  }

  @override
  void updateHeight(int height) {
    final h = height.clamp(0, 4096);
    state = state.copyWith(
      height: h,
      scaleMultiplier: (state.width == 0 && h == 0) ? 1.0 : null,
      formError: null,
    );
  }

  @override
  void updateScaleMultiplier(double multiplier) {
    // 选倍数 = 等比语义:重置宽高为 0(原图等比),仅存偏好,保证
    // 入队时"宽高全 0 且倍数非 1"的展开条件可达
    state = state.copyWith(
      width: 0,
      height: 0,
      scaleMultiplier: multiplier,
      formError: null,
    );
  }

  @override
  void updateLoop(int loop) {
    state = state.copyWith(loop: loop.clamp(0, 100), formError: null);
  }

  @override
  void updatePlaybackSpeed(double speed) {
    state = state.copyWith(
      playbackSpeed: speed.clamp(0.25, 4),
      formError: null,
    );
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

  // ---- 文本输入解析+校验(短路语义,见接口注释) ----

  @override
  bool tryUpdateLoopText(String text) {
    final v = int.tryParse(text.trim());
    if (v == null) {
      state = state.copyWith(formError: '循环次数须为数字');
      return false;
    }
    updateLoop(v);
    return true;
  }

  @override
  bool tryUpdateStartText(String text) {
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      state = state.copyWith(formError: '开始时间格式非法(示例 00:03.200)');
      return false;
    }
    updateStart(parsed);
    return true;
  }

  @override
  bool tryUpdateEndText(String text) {
    if (text.trim().isEmpty) {
      updateEnd(null);
      return true;
    }
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      state = state.copyWith(formError: '结束时间格式非法(示例 00:09.500)');
      return false;
    }
    updateEnd(parsed);
    return true;
  }

  @override
  bool tryUpdateCustomWidth(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      state = state.copyWith(formError: '宽度须为 1–4096 的数字');
      return false;
    }
    updateWidth(v);
    return true;
  }

  @override
  bool tryUpdateCustomHeight(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      state = state.copyWith(formError: '高度须为 1–4096 的数字');
      return false;
    }
    updateHeight(v);
    return true;
  }

  @override
  bool tryUpdateCustomScaleMultiplier(String text) {
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0 || v > 4) {
      state = state.copyWith(formError: '缩放倍数须为 0.1–4 的数字');
      return false;
    }
    updateScaleMultiplier(v);
    return true;
  }

  @override
  Future<void> pickOutputDir() {
    // 目录选择公共动作(export/image_gif/batch 共用,见 output_dir_picker)
    return output_dir_picker.pickOutputDir(
      ref: ref,
      currentOutputDir: state.outputDir,
      locked: false,
      onPicked: updateOutputDir,
      onError: (message) => state = state.copyWith(formError: message),
    );
  }

  @override
  void updateFormError(String message) {
    state = state.copyWith(formError: message);
  }

  @override
  void clearFormError() {
    state = state.copyWith(formError: null);
  }

  /// 表单 → GifSetting(end 保留 null,由 TaskManager 装配视频时长;
  /// 倍数 null = 自定义,持久化时归一为 1.0)。
  GifSetting assembleSetting() => GifSetting(
    fps: state.fps,
    width: state.width,
    height: state.height,
    loop: state.loop,
    start: state.start,
    end: state.end,
    scaleMultiplier: state.scaleMultiplier ?? 1.0,
    playbackSpeed: state.playbackSpeed,
  );

  /// 起止归一化:负值钳 0,end 为 null 保持 null;均非空时自动交换。
  (Duration, Duration?) _normalized(Duration start, Duration? end) {
    final s = start.isNegative ? Duration.zero : start;
    if (end == null) return (s, null);
    final e = end.isNegative ? Duration.zero : end;
    return normalizeRange(s, e);
  }
}

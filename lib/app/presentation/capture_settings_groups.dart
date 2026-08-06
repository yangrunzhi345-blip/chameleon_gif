import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/export/presentation/param_dropdown_field.dart';

import '../application/camera_settings_controller.dart';
import '../application/record_settings_controller.dart';

/// 设置页相机分组(设备支持什么显示什么;docs/18 C1-WP4)。
///
/// 能力探测失败(capabilities null)→ 仅基础参数(帧率/时长/闪光灯)
/// + 降级提示;参数变更即 applyParams(体验增强,拍摄正确性不依赖)。
class CameraSettingsGroup extends ConsumerWidget {
  const CameraSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraSettingsControllerProvider);
    final controller = ref.read(cameraSettingsControllerProvider.notifier);
    final params = state.params;
    final caps = state.capabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 设备选择(枚举失败 → 隐藏,默认后置)
        if (state.devices.length > 1) ...[
          Text('拍摄设备', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              for (final d in state.devices)
                ButtonSegment(value: d.id, label: Text(d.name)),
            ],
            selected: {state.deviceId},
            onSelectionChanged: (s) => controller.updateDeviceId(s.first),
          ),
          const SizedBox(height: 12),
        ],
        if (caps == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '部分相机参数不可用(能力探测失败)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        // 基础参数(三平台)
        _Row(
          label: '帧率',
          child: ParamDropdownField<double>(
            value: params.fps,
            items: const [
              ParamDropdownItem(15.0, '15 fps'),
              ParamDropdownItem(24.0, '24 fps'),
              ParamDropdownItem(30.0, '30 fps'),
            ],
            onChanged: (v) => controller.updateParams(params.copyWith(fps: v)),
          ),
        ),
        const SizedBox(height: 12),
        _Row(
          label: '时长上限',
          child: ParamDropdownField<int>(
            value: params.maxDurationMs,
            items: const [
              ParamDropdownItem(15000, '15 秒'),
              ParamDropdownItem(30000, '30 秒'),
              ParamDropdownItem(60000, '60 秒'),
            ],
            onChanged: (v) =>
                controller.updateParams(params.copyWith(maxDurationMs: v)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('闪光灯'),
          value: params.flashOn,
          onChanged: (v) =>
              controller.updateParams(params.copyWith(flashOn: v)),
        ),
        // 桌面端分辨率行(能力探测通过才显示;Android 不设分辨率 D3)
        if (caps?.supportsResolution ?? false) ...[
          const SizedBox(height: 12),
          _Row(
            label: '分辨率',
            child: ParamDropdownField<CaptureResolution>(
              value: _currentResolution(params, caps!),
              items: [
                for (final r in caps.supportedResolutions)
                  ParamDropdownItem(r, r.toString()),
              ],
              onChanged: (r) => controller.updateParams(
                params.copyWith(
                  resolutionWidth: r.width,
                  resolutionHeight: r.height,
                ),
              ),
            ),
          ),
        ],
        // 桌面第二档控制面板(v4l2 控制项;能力探测驱动,无面板 = 无控制)
        if (caps?.controls.isNotEmpty ?? false) ...[
          const SizedBox(height: 16),
          Text('相机控制', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          for (final control in caps!.controls)
            _V4l2ControlTile(
              control: control,
              value: params.v4l2Controls[control.id] ?? control.value,
              onChanged: (v) => controller.updateParams(
                params.copyWith(
                  v4l2Controls: {...params.v4l2Controls, control.id: v},
                ),
              ),
            ),
        ],
        // 能力参数(探测通过才显示)
        if (caps?.supportsExposureOffset ?? false) ...[
          _Row(
            label: '曝光补偿',
            child: Slider(
              value: params.exposureCompensation ?? 0,
              min: caps!.exposureOffsetMin,
              max: caps.exposureOffsetMax,
              divisions: math.max(
                1,
                ((caps.exposureOffsetMax - caps.exposureOffsetMin) /
                        caps.exposureOffsetStep)
                    .round(),
              ),
              onChanged: (v) => controller.updateParams(
                params.copyWith(exposureCompensation: v),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('曝光锁定'),
            value: params.exposureLock,
            onChanged: (v) =>
                controller.updateParams(params.copyWith(exposureLock: v)),
          ),
        ],
        if ((caps?.supportsZoom ?? false) && caps != null) ...[
          _Row(
            label: '变焦',
            child: Slider(
              value: params.zoom ?? caps.zoomMin,
              min: caps.zoomMin,
              max: caps.zoomMax,
              onChanged: (v) =>
                  controller.updateParams(params.copyWith(zoom: v)),
            ),
          ),
        ],
        if (caps?.focusModes.isNotEmpty ?? false) ...[
          _Row(
            label: '对焦模式',
            child: ParamDropdownField<FocusMode>(
              value: params.focusMode,
              items: [
                for (final m in caps!.focusModes)
                  ParamDropdownItem(m, _focusLabel(m)),
              ],
              onChanged: (v) =>
                  controller.updateParams(params.copyWith(focusMode: v)),
            ),
          ),
        ],
      ],
    );
  }

  static String _focusLabel(FocusMode mode) => switch (mode) {
    FocusMode.auto => '自动',
    FocusMode.continuous => '连续',
    FocusMode.manual => '手动',
  };

  /// 当前分辨率(未设置 → 候选最大项,即列表首个)。
  static CaptureResolution _currentResolution(
    CaptureParams params,
    CameraCapabilities caps,
  ) {
    final res = caps.supportedResolutions;
    if (res.isEmpty) return const CaptureResolution(width: 0, height: 0);
    return res.firstWhere(
      (r) =>
          r.width == params.resolutionWidth &&
          r.height == params.resolutionHeight,
      orElse: () => res.first,
    );
  }
}

/// v4l2 控制项中文标签白名单(面板显示友好名称;未收录项显示原始 id)。
const _controlLabels = <String, String>{
  'brightness': '亮度',
  'contrast': '对比度',
  'saturation': '饱和度',
  'hue': '色相',
  'gamma': '伽马',
  'sharpness': '锐度',
  'white_balance_automatic': '自动白平衡',
  'white_balance_temperature': '白平衡色温',
  'auto_exposure': '自动曝光',
  'exposure_time_absolute': '曝光时间',
  'backlight_compensation': '背光补偿',
  'power_line_frequency': '电源频率',
};

/// 第二档控制项行(int → Slider / bool → Switch / menu → Dropdown;
/// inactive 置灰 —— 自动模式联动,如自动白平衡开启时色温项)。
class _V4l2ControlTile extends StatelessWidget {
  const _V4l2ControlTile({
    required this.control,
    required this.value,
    required this.onChanged,
  });

  final CameraControlCapability control;
  final int? value;

  /// 值变更回调(目标值;面板仅渲染与转发,无业务逻辑)。
  final void Function(int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = control.active && value != null;
    final label = _controlLabels[control.id] ?? control.id;
    final opacity = control.active ? 1.0 : 0.5;
    return Opacity(
      opacity: opacity,
      child: switch (control.kind) {
        CameraControlKind.bool => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value != 0,
          onChanged: enabled ? (v) => onChanged(v ? 1 : 0) : null,
        ),
        CameraControlKind.int => _Row(label: label, child: _buildSlider()),
        CameraControlKind.menu => _Row(
          label: label,
          child: _buildMenu(context),
        ),
      },
    );
  }

  Widget _buildSlider() {
    final min = control.min ?? 0;
    final max = control.max ?? 1;
    final step = control.step ?? 1;
    final divisions = step > 0 && max > min
        ? math.max(1, ((max - min) / step).round())
        : 1;
    return Slider(
      value: (value ?? min).clamp(min, max).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: divisions,
      onChanged: control.active && value != null
          ? (v) => onChanged(v.round())
          : null,
    );
  }

  Widget _buildMenu(BuildContext context) {
    final choices = control.choices ?? const <int, String>{};
    return DropdownButton<int>(
      value: choices.containsKey(value) ? value : choices.keys.firstOrNull,
      isExpanded: true,
      items: [
        for (final e in choices.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: control.active && value != null
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
    );
  }
}

/// 设置页录屏分组(帧率/时长上限/虚拟显示比例;docs/19 S1-WP4)。
///
/// Android 恒全屏(虚拟显示比例经 aspectRatio),能力固定无探测;
/// 参数变更仅更新状态,保存时持久化(record_params)。
class RecordSettingsGroup extends ConsumerWidget {
  const RecordSettingsGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordSettingsControllerProvider);
    final controller = ref.read(recordSettingsControllerProvider.notifier);
    final params = state.params;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Row(
          label: '帧率',
          child: ParamDropdownField<double>(
            value: params.fps,
            items: const [
              ParamDropdownItem(5.0, '5 fps'),
              ParamDropdownItem(10.0, '10 fps'),
              ParamDropdownItem(15.0, '15 fps'),
              ParamDropdownItem(20.0, '20 fps'),
              ParamDropdownItem(30.0, '30 fps'),
            ],
            onChanged: (v) => controller.updateParams(params.copyWith(fps: v)),
          ),
        ),
        const SizedBox(height: 12),
        _Row(
          label: '时长上限',
          child: ParamDropdownField<int>(
            value: params.maxDurationMs,
            items: const [
              ParamDropdownItem(30000, '30 秒'),
              ParamDropdownItem(60000, '60 秒'),
              ParamDropdownItem(120000, '120 秒'),
            ],
            onChanged: (v) =>
                controller.updateParams(params.copyWith(maxDurationMs: v)),
          ),
        ),
        const SizedBox(height: 12),
        _Row(
          label: '画面比例',
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'native', label: Text('全屏原生')),
              ButtonSegment(value: '16:9', label: Text('16:9')),
            ],
            selected: {params.aspectRatio == null ? 'native' : '16:9'},
            onSelectionChanged: (s) => controller.updateParams(
              params.copyWith(aspectRatio: s.first == '16:9' ? 16 / 9 : null),
            ),
          ),
        ),
      ],
    );
  }
}

/// 行布局:左标签 + 右控件。
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(child: child),
      ],
    );
  }
}

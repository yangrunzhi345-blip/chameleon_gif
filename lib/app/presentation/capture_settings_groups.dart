import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

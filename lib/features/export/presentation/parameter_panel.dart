import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../application/estimate_size.dart';
import '../application/export_providers.dart';
import '../application/export_state.dart';
import 'export_action_area.dart';

/// 参数面板(P4-WP2,docs/10 §10.3.1):输出/时间/目录分组表单。
///
/// 纯渲染与事件转发:控件 → [ExportController] 表单方法;时间文本失焦/回车
/// 才提交(parseFfmpegTime,非法 → formError 红字 + 禁用导出);
/// 预估大小由表单字段经 [estimateGifSize] 计算(纯展示)。
class ParameterPanel extends ConsumerStatefulWidget {
  const ParameterPanel({super.key, required this.video, this.enabled = true});

  final VideoInfo video;
  final bool enabled;

  @override
  ConsumerState<ParameterPanel> createState() => _ParameterPanelState();
}

class _ParameterPanelState extends ConsumerState<ParameterPanel> {
  final _loopCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  bool _loopFocused = false;
  bool _startFocused = false;
  bool _endFocused = false;

  static const _fpsOptions = [
    8.0,
    10.0,
    12.0,
    15.0,
    20.0,
    24.0,
    30.0,
    50.0,
    60.0,
  ];
  static const _widthOptions = [
    0,
    240,
    320,
    480,
    640,
    720,
    960,
    1080,
    1280,
    1920,
  ];

  @override
  void dispose() {
    _loopCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  /// 未聚焦时从 state 回填文本(时间轴拖动提交后文本随之刷新)。
  void _syncTextFields(ExportFormState state) {
    if (!_loopFocused) _loopCtrl.text = '${state.loop}';
    if (!_startFocused) {
      _startCtrl.text = _formatTimeInput(state.start);
    }
    if (!_endFocused) {
      _endCtrl.text = state.end == null ? '' : _formatTimeInput(state.end!);
    }
  }

  String _formatTimeInput(Duration d) {
    final total = d.inMilliseconds;
    final m = (total ~/ 60000).toString().padLeft(2, '0');
    final s = ((total % 60000) / 1000).toStringAsFixed(3).padLeft(6, '0');
    return '$m:$s';
  }

  void _submitStart(String text) {
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('开始时间格式非法(示例 00:03.200)');
      return;
    }
    ref.read(exportControllerProvider.notifier).updateStart(parsed);
  }

  void _submitEnd(String text) {
    if (text.trim().isEmpty) {
      ref.read(exportControllerProvider.notifier).updateEnd(null);
      return;
    }
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('结束时间格式非法(示例 00:09.500)');
      return;
    }
    ref.read(exportControllerProvider.notifier).updateEnd(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exportControllerProvider);
    _syncTextFields(state);
    final enabled = widget.enabled && !state.locked;
    final controller = ref.read(exportControllerProvider.notifier);
    final video = widget.video;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel('输出'),
          _ParamRow(
            label: '帧率',
            child: DropdownButton<double>(
              value: state.fps,
              items: [
                for (final fps in _fpsOptions)
                  DropdownMenuItem(value: fps, child: Text('$fps fps')),
              ],
              onChanged: enabled
                  ? (v) {
                      if (v != null) controller.updateFps(v);
                    }
                  : null,
            ),
          ),
          _ParamRow(
            label: '宽度',
            child: DropdownButton<int>(
              value: state.width,
              items: [
                for (final w in _widthOptions)
                  DropdownMenuItem(
                    value: w,
                    child: Text(w == 0 ? '原图等比' : '$w px'),
                  ),
              ],
              onChanged: enabled
                  ? (v) {
                      if (v != null) controller.updateWidth(v);
                    }
                  : null,
            ),
          ),
          _ParamRow(
            label: '循环',
            child: TextField(
              controller: _loopCtrl,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '0 = 无限循环'),
              onChanged: (_) => _loopFocused = true,
              onTap: () => _loopFocused = true,
              onSubmitted: (text) {
                _loopFocused = false;
                final v = int.tryParse(text.trim());
                if (v == null) {
                  controller.updateFormError('循环次数须为数字');
                } else {
                  controller.updateLoop(v);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel('时间'),
          _ParamRow(
            label: '开始',
            child: TextField(
              controller: _startCtrl,
              enabled: enabled,
              decoration: const InputDecoration(hintText: '00:00.000'),
              onChanged: (_) => _startFocused = true,
              onTap: () => _startFocused = true,
              onSubmitted: (text) {
                _startFocused = false;
                _submitStart(text);
              },
            ),
          ),
          _ParamRow(
            label: '结束',
            child: TextField(
              controller: _endCtrl,
              enabled: enabled,
              decoration: const InputDecoration(hintText: '留空 = 到结尾'),
              onChanged: (_) => _endFocused = true,
              onTap: () => _endFocused = true,
              onSubmitted: (text) {
                _endFocused = false;
                _submitEnd(text);
              },
            ),
          ),
          if (state.formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state.formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          _SectionLabel('目录'),
          // 目录选择区在 P4-WP4 落地(选择按钮 + 路径显示)
          Text(
            state.outputDir ?? '系统临时目录(默认)',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '预估大小:${_estimateLabel(state, video)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: enabled ? controller.saveAsDefault : null,
                child: const Text('存为默认'),
              ),
              TextButton(
                onPressed: enabled ? controller.loadDefault : null,
                child: const Text('载入默认'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExportActionArea(video: video, enabled: enabled),
        ],
      ),
    );
  }

  String _estimateLabel(ExportFormState state, VideoInfo video) {
    final bytes = estimateGifSize(
      setting: GifSetting(
        fps: state.fps,
        width: state.width,
        loop: state.loop,
        start: state.start,
        end: state.end,
      ),
      video: video,
    );
    return bytes <= 0 ? '—' : formatFileSize(bytes);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

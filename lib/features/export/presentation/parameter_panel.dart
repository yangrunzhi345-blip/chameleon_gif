import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../core/utils/file_size.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../application/aspect_ratio.dart';
import '../application/estimate_size.dart';
import '../application/export_providers.dart';
import '../application/export_state.dart';
import '../application/scale_multiplier.dart';
import 'custom_value_dialog.dart';
import 'export_action_area.dart';
import 'param_dropdown_field.dart';

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
  final _loopFocusNode = FocusNode();
  final _startFocusNode = FocusNode();
  final _endFocusNode = FocusNode();
  bool _loopFocused = false;
  bool _startFocused = false;
  bool _endFocused = false;

  @override
  void initState() {
    super.initState();
    // 失焦即提交(状态即时同步;导出前另有 flush 兜底)
    _loopFocusNode.addListener(_onLoopBlur);
    _startFocusNode.addListener(_onStartBlur);
    _endFocusNode.addListener(_onEndBlur);
  }

  /// 循环输入框失焦 → 提交(不回车也生效)。
  void _onLoopBlur() {
    if (!_loopFocusNode.hasFocus) _submitLoopText(_loopCtrl.text);
  }

  /// 开始时间输入框失焦 → 提交(不回车也生效)。
  void _onStartBlur() {
    if (!_startFocusNode.hasFocus) _submitStart(_startCtrl.text);
  }

  /// 结束时间输入框失焦 → 提交(不回车也生效)。
  void _onEndBlur() {
    if (!_endFocusNode.hasFocus) _submitEnd(_endCtrl.text);
  }

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
  static const _speedOptions = [0.25, 0.5, 1.0, 2.0, 3.0, 4.0];

  /// 面板输入控件统一边框(与 ParamDropdownField 收起态一致)。
  static const _panelInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  @override
  void dispose() {
    _loopFocusNode.removeListener(_onLoopBlur);
    _startFocusNode.removeListener(_onStartBlur);
    _endFocusNode.removeListener(_onEndBlur);
    _loopCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _loopFocusNode.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  /// 循环文本提交(解析失败 → formError)。
  void _submitLoopText(String text) {
    final v = int.tryParse(text.trim());
    if (v == null) {
      ref.read(exportControllerProvider.notifier).updateFormError('循环次数须为数字');
    } else {
      ref.read(exportControllerProvider.notifier).updateLoop(v);
    }
  }

  /// 未聚焦时从 state 回填文本(时间轴拖动提交后文本随之刷新)。
  void _syncTextFields(ExportFormState state) {
    if (!_loopFocused) _loopCtrl.text = '${state.loop}';
    if (!_startFocused) {
      _startCtrl.text = formatMmSs(
        state.start.inMilliseconds,
        fractionDigits: 3,
      );
    }
    if (!_endFocused) {
      _endCtrl.text = state.end == null
          ? ''
          : formatMmSs(state.end!.inMilliseconds, fractionDigits: 3);
    }
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

  /// 提交未回车的文本字段(循环/开始/结束)到控制器。
  ///
  /// 先对全部字段做纯解析校验(任一非法 → formError 并返回 false),再
  /// 逐项提交(update* 内部钳制失败同样中止)。**必须先全量校验再提交**:
  /// 各 update* 成功后都会清 formError,顺序逐项提交会让前项错误被后项
  /// 成功清除。调用方(导出入口)在返回 false 时中止动作。
  bool flushPendingInputs() {
    final loop = int.tryParse(_loopCtrl.text.trim());
    final start = parseFfmpegTime(_startCtrl.text);
    final endText = _endCtrl.text.trim();
    final end = endText.isEmpty ? null : parseFfmpegTime(endText);
    if (loop == null) {
      ref.read(exportControllerProvider.notifier).updateFormError('循环次数须为数字');
      return false;
    }
    if (start == null) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('开始时间格式非法(示例 00:03.200)');
      return false;
    }
    if (endText.isNotEmpty && end == null) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('结束时间格式非法(示例 00:09.500)');
      return false;
    }
    _loopFocused = false;
    _startFocused = false;
    _endFocused = false;
    final controller = ref.read(exportControllerProvider.notifier);
    controller.updateLoop(loop);
    controller.updateStart(start);
    controller.updateEnd(end);
    return ref.read(exportControllerProvider).formError == null;
  }

  /// 自定义宽度:弹输入框,1–4096 校验(非法 → formError)。
  Future<void> _customWidth() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义宽度',
      initialValue: '${ref.read(exportControllerProvider).width}',
      hintText: '1–4096',
    );
    if (text == null) return;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('宽度须为 1–4096 的数字');
      return;
    }
    ref.read(exportControllerProvider.notifier).updateWidth(v);
  }

  /// 自定义高度:弹输入框,1–4096 校验(非法 → formError)。
  Future<void> _customHeight() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义高度',
      initialValue: '${ref.read(exportControllerProvider).height}',
      hintText: '1–4096',
    );
    if (text == null) return;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('高度须为 1–4096 的数字');
      return;
    }
    ref.read(exportControllerProvider.notifier).updateHeight(v);
  }

  /// 自定义缩放倍数:弹输入框,0.1–4 校验(非法 → formError)。
  Future<void> _customScaleMultiplier() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义缩放倍数',
      initialValue:
          '${ref.read(exportControllerProvider).scaleMultiplier ?? 1.0}',
      hintText: '0.1–4',
    );
    if (text == null) return;
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0 || v > 4) {
      ref
          .read(exportControllerProvider.notifier)
          .updateFormError('缩放倍数须为 0.1–4 的数字');
      return;
    }
    ref.read(exportControllerProvider.notifier).updateScaleMultiplier(v);
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
            child: ParamDropdownField<double>(
              value: state.fps,
              enabled: enabled,
              items: [
                for (final fps in _fpsOptions)
                  ParamDropdownItem(fps, '${fps.toInt()} fps'),
              ],
              onChanged: controller.updateFps,
            ),
          ),
          _ParamRow(
            label: '缩放倍数',
            child: ParamDropdownField<double?>(
              value: state.scaleMultiplier,
              enabled: enabled,
              items: [
                for (final m in kScaleMultiplierOptions)
                  ParamDropdownItem<double?>(
                    m,
                    '${m == m.roundToDouble() ? m.toInt() : m} 倍',
                  ),
                // null 哨兵 = 自定义倍数(点击弹输入框)
                const ParamDropdownItem<double?>(null, '自定义'),
              ],
              // 收起态:null = 自定义(手动宽高);非选项值(自定义倍数)
              // 显示具体值(如 1.25 倍)
              valueLabelBuilder: (v) {
                if (v == null) return '自定义';
                return '${v == v.roundToDouble() ? v.toInt() : v} 倍';
              },
              onChanged: (m) {
                if (m == null) {
                  _customScaleMultiplier();
                  return;
                }
                controller.updateScaleMultiplier(m);
              },
            ),
          ),
          _ParamRow(
            label: '宽度',
            child: ParamDropdownField<int>(
              value: state.width,
              enabled: enabled,
              items: [
                for (final w in _widthOptions)
                  ParamDropdownItem(w, w == 0 ? '原图等比' : '$w px'),
                // -1 哨兵 = 自定义宽度(选项表 0–1920 不冲突;点击弹输入框)
                const ParamDropdownItem(-1, '自定义'),
              ],
              // 倍数联动算出的尺寸可能不在选项表(如 128px)→ 显示具体值
              valueLabelBuilder: (w) => w == 0 ? '原图等比' : '$w px',
              onChanged: (w) {
                if (w == -1) {
                  _customWidth();
                  return;
                }
                controller.updateWidth(w);
              },
            ),
          ),
          _ParamRow(
            label: '高度',
            child: ParamDropdownField<int>(
              value: state.height,
              enabled: enabled,
              items: [
                for (final h in _widthOptions)
                  ParamDropdownItem(h, h == 0 ? '原图等比' : '$h px'),
                const ParamDropdownItem(-1, '自定义'),
              ],
              valueLabelBuilder: (h) => h == 0 ? '原图等比' : '$h px',
              onChanged: (h) {
                if (h == -1) {
                  _customHeight();
                  return;
                }
                controller.updateHeight(h);
              },
            ),
          ),
          _ParamRow(
            label: '循环',
            child: TextField(
              controller: _loopCtrl,
              focusNode: _loopFocusNode,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0 = 无限循环',
                border: _panelInputBorder,
              ),
              onChanged: (_) => _loopFocused = true,
              onTap: () => _loopFocused = true,
              onSubmitted: (text) {
                _loopFocused = false;
                _submitLoopText(text);
              },
            ),
          ),
          _ParamRow(
            label: '速度',
            child: ParamDropdownField<double>(
              value: state.playbackSpeed,
              enabled: enabled,
              items: [
                // 0.25/0.5 慢放、1 正常、≥2 加速
                for (final s in _speedOptions)
                  ParamDropdownItem(
                    s,
                    '${s == s.roundToDouble() ? s.toInt() : s} 倍',
                  ),
              ],
              onChanged: controller.updatePlaybackSpeed,
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel('时间'),
          _ParamRow(
            label: '开始',
            child: TextField(
              controller: _startCtrl,
              focusNode: _startFocusNode,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: '00:00.000',
                border: _panelInputBorder,
              ),
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
              focusNode: _endFocusNode,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: '留空 = 到结尾',
                border: _panelInputBorder,
              ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  state.outputDir ?? '系统临时目录(默认)',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: enabled ? controller.pickOutputDir : null,
                child: const Text('选择目录'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 提醒区:比例不一致 / 体积过大(可同时出现,均不阻塞导出)
          if (_showAspectWarning(state, video) ||
              _showSizeWarning(state, video))
            Column(
              children: [
                if (_showAspectWarning(state, video))
                  _AspectWarning(
                    width: state.width,
                    height: state.height,
                    videoWidth: video.width,
                    videoHeight: video.height,
                  ),
                if (_showSizeWarning(state, video))
                  _SizeWarning(sizeLabel: _estimateLabel(state, video)),
              ],
            ),
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
          ExportActionArea(
            video: video,
            enabled: enabled,
            // 导出前 flush 未回车的文本字段(循环/开始/结束)
            onBeforeSubmit: flushPendingInputs,
          ),
        ],
      ),
    );
  }

  String _estimateLabel(ExportFormState state, VideoInfo video) {
    final bytes = _estimateBytes(state, video);
    return bytes <= 0 ? '—' : formatFileSize(bytes);
  }

  /// 当前表单的预估输出字节数(预估文本与体积提醒共用)。
  int _estimateBytes(ExportFormState state, VideoInfo video) {
    return estimateGifSize(
      setting: GifSetting(
        fps: state.fps,
        width: state.width,
        height: state.height,
        loop: state.loop,
        start: state.start,
        end: state.end,
      ),
      video: video,
    );
  }

  /// 宽高同时指定且比例与源视频不一致时显示变形警告(不阻塞导出)。
  bool _showAspectWarning(ExportFormState state, VideoInfo video) {
    return !isAspectRatioMatch(
      GifSetting(width: state.width, height: state.height),
      video,
    );
  }

  /// 预估输出超过 [kGifSizeWarningBytes](50MB)时显示体积提醒。
  bool _showSizeWarning(ExportFormState state, VideoInfo video) {
    return _estimateBytes(state, video) > kGifSizeWarningBytes;
  }
}

/// 体积提醒条:预估输出较大,提示耗时与磁盘占用(不阻塞导出)。
class _SizeWarning extends StatelessWidget {
  const _SizeWarning({required this.sizeLabel});

  /// 已格式化的预估体积(如 "65 MB")。
  final String sizeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '预计输出约 $sizeLabel,体积较大;导出耗时与磁盘占用较高,'
              '仍可继续。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 比例不一致警告条:提示输出会变形,导出按钮保持可用(用户可继续)。
class _AspectWarning extends StatelessWidget {
  const _AspectWarning({
    required this.width,
    required this.height,
    required this.videoWidth,
    required this.videoHeight,
  });

  final int width;
  final int height;
  final int videoWidth;
  final int videoHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: scheme.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '输出 $width×$height 与源视频 $videoWidth×$videoHeight '
              '比例不一致,画面将被拉伸变形;如仍需要可继续导出。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.tertiary),
            ),
          ),
        ],
      ),
    );
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

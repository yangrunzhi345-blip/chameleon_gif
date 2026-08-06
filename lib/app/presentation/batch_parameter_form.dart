import 'package:flutter/material.dart';

import '../../core/utils/duration_format.dart';
import '../../features/export/application/scale_multiplier.dart';
import '../../features/export/presentation/custom_value_dialog.dart';
import '../../features/export/presentation/param_dropdown_field.dart';
import '../application/batch_form_mixin.dart';
import '../application/batch_import_state.dart';

/// 批量参数表单公共组件(纯渲染与事件转发,provider 无关)。
///
/// 批量导入设置页与设置界面(批量导入默认参数)共用:输出/时间/目录
/// 三分组,控件经 [BatchFormActions] 转发,显示值来自 [state]。
/// 时间文本失焦/回车才提交(parseFfmpegTime 校验,非法 → formError);
/// 结束留空 = 到结尾(null)。[BatchImportScreen] 与 [SettingsScreen]
/// 接线一行:`BatchParameterForm(state: s, actions: ref.read(...notifier))`。
class BatchParameterForm extends StatefulWidget {
  const BatchParameterForm({
    super.key,
    required this.state,
    required this.actions,
  });

  /// 表单显示值(由页面 watch 的控制器状态传入)。
  final BatchImportFormState state;

  /// 事件转发目标(批量会话/设置页控制器,均实现 [BatchFormActions])。
  final BatchFormActions actions;

  @override
  State<BatchParameterForm> createState() => _BatchParameterFormState();
}

class _BatchParameterFormState extends State<BatchParameterForm> {
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

  /// 面板输入控件统一边框(与 ParamDropdownField 收起态一致)。
  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  @override
  void dispose() {
    _loopCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  /// 未聚焦时从 state 回填文本(参数变更后文本随之刷新)。
  void _syncTextFields(BatchImportFormState state) {
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
      widget.actions.updateFormError('开始时间格式非法(示例 00:03.200)');
      return;
    }
    widget.actions.updateStart(parsed);
  }

  void _submitEnd(String text) {
    if (text.trim().isEmpty) {
      widget.actions.updateEnd(null);
      return;
    }
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      widget.actions.updateFormError('结束时间格式非法(示例 00:09.500)');
      return;
    }
    widget.actions.updateEnd(parsed);
  }

  /// 自定义宽度:弹输入框,1–4096 校验(非法 → formError)。
  Future<void> _customWidth() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义宽度',
      initialValue: '${widget.state.width}',
      hintText: '1–4096',
    );
    if (text == null) return;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      widget.actions.updateFormError('宽度须为 1–4096 的数字');
      return;
    }
    widget.actions.updateWidth(v);
  }

  /// 自定义高度:弹输入框,1–4096 校验(非法 → formError)。
  Future<void> _customHeight() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义高度',
      initialValue: '${widget.state.height}',
      hintText: '1–4096',
    );
    if (text == null) return;
    final v = int.tryParse(text.trim());
    if (v == null || v < 1 || v > 4096) {
      widget.actions.updateFormError('高度须为 1–4096 的数字');
      return;
    }
    widget.actions.updateHeight(v);
  }

  /// 宽高收起态文案:当前为原图等比(0)且选了倍数(非 1)时,显示
  /// "原图等比 <倍数>"(与缩放倍数联动,菜单内选项不变);其余情形
  /// 返回 null 走默认 label(原图等比 / 具体像素)。
  String? _dimensionLabel(int dimension) {
    if (dimension != 0) return null;
    final m = widget.state.scaleMultiplier;
    if (m == null || (m - 1.0).abs() <= 1e-9) return null;
    final text = m == m.roundToDouble() ? '${m.toInt()}' : '$m';
    return '原图等比 $text';
  }

  /// 自定义缩放倍数:弹输入框,0.1–4 校验(非法 → formError)。
  Future<void> _customScaleMultiplier() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义缩放倍数',
      initialValue: '${widget.state.scaleMultiplier ?? 1.0}',
      hintText: '0.1–4',
    );
    if (text == null) return;
    final v = double.tryParse(text.trim());
    if (v == null || v <= 0 || v > 4) {
      widget.actions.updateFormError('缩放倍数须为 0.1–4 的数字');
      return;
    }
    widget.actions.updateScaleMultiplier(v);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final actions = widget.actions;
    _syncTextFields(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('输出'),
        ParamRow(
          label: '帧率',
          child: ParamDropdownField<double>(
            value: state.fps,
            items: [
              for (final fps in _fpsOptions)
                ParamDropdownItem(fps, '${fps.toInt()} fps'),
            ],
            onChanged: actions.updateFps,
          ),
        ),
        ParamRow(
          label: '缩放倍数',
          child: ParamDropdownField<double?>(
            value: state.scaleMultiplier,
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
              actions.updateScaleMultiplier(m);
            },
          ),
        ),
        ParamRow(
          label: '宽度',
          child: ParamDropdownField<int>(
            value: state.width,
            // 选倍数后收起态显示"原图等比 0.75"(菜单内选项不变)
            labelOverride: _dimensionLabel(state.width),
            items: [
              for (final w in _widthOptions)
                ParamDropdownItem(w, w == 0 ? '原图等比' : '$w px'),
              // -1 哨兵 = 自定义宽度(选项表 0–1920 不冲突;点击弹输入框)
              const ParamDropdownItem(-1, '自定义'),
            ],
            // 倍数联动算出的尺寸可能不在选项表 → 显示具体值
            valueLabelBuilder: (w) => w == 0 ? '原图等比' : '$w px',
            onChanged: (w) {
              if (w == -1) {
                _customWidth();
                return;
              }
              actions.updateWidth(w);
            },
          ),
        ),
        ParamRow(
          label: '高度',
          child: ParamDropdownField<int>(
            value: state.height,
            labelOverride: _dimensionLabel(state.height),
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
              actions.updateHeight(h);
            },
          ),
        ),
        ParamRow(
          label: '循环',
          child: TextField(
            controller: _loopCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '0 = 无限循环',
              border: _inputBorder,
            ),
            onChanged: (_) => _loopFocused = true,
            onTap: () => _loopFocused = true,
            onSubmitted: (text) {
              _loopFocused = false;
              final v = int.tryParse(text.trim());
              if (v == null) {
                actions.updateFormError('循环次数须为数字');
              } else {
                actions.updateLoop(v);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        const SectionLabel('时间'),
        ParamRow(
          label: '开始',
          child: TextField(
            controller: _startCtrl,
            decoration: const InputDecoration(
              hintText: '00:00.000',
              border: _inputBorder,
            ),
            onChanged: (_) => _startFocused = true,
            onTap: () => _startFocused = true,
            onSubmitted: (text) {
              _startFocused = false;
              _submitStart(text);
            },
          ),
        ),
        ParamRow(
          label: '结束',
          child: TextField(
            controller: _endCtrl,
            decoration: const InputDecoration(
              hintText: '留空 = 到结尾',
              border: _inputBorder,
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
        const SectionLabel('目录'),
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
              onPressed: actions.pickOutputDir,
              child: const Text('选择目录'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 表单分组标题(公开供设置页等复用)。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

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

/// 表单行(标签 + 控件,公开供设置页等复用)。
class ParamRow extends StatelessWidget {
  const ParamRow({super.key, required this.label, required this.child});

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

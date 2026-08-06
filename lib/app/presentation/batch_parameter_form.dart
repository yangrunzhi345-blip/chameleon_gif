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
  State<BatchParameterForm> createState() => BatchParameterFormState();
}

class BatchParameterFormState extends State<BatchParameterForm> {
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
    // 失焦即提交(状态即时同步;保存前另有 flush 兜底)
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

  /// 循环文本提交(解析/校验在控制器 tryUpdateLoopText)。
  void _submitLoopText(String text) {
    widget.actions.tryUpdateLoopText(text);
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
  static const _inputBorder = OutlineInputBorder(
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
    widget.actions.tryUpdateStartText(text);
  }

  void _submitEnd(String text) {
    widget.actions.tryUpdateEndText(text);
  }

  /// 提交未回车的文本字段(循环/开始/结束)到控制器。
  ///
  /// 短路语义:逐字段调控制器 try*(解析/格式校验/错误文案都在控制器),
  /// **任一失败立即返回 false** —— 后项成功(update* 清 formError)不会
  /// 清掉前项错误。不读 [widget.state.formError](父组件 build 快照,
  /// 同步提交后尚未重建);formError 非空时保存入口本就被禁用。
  bool flushPendingInputs() {
    _loopFocused = false;
    _startFocused = false;
    _endFocused = false;
    final actions = widget.actions;
    if (!actions.tryUpdateLoopText(_loopCtrl.text)) return false;
    if (!actions.tryUpdateStartText(_startCtrl.text)) return false;
    if (!actions.tryUpdateEndText(_endCtrl.text)) return false;
    return true;
  }

  /// 自定义宽度:弹输入框(校验在控制器 tryUpdateCustomWidth)。
  Future<void> _customWidth() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义宽度',
      initialValue: '${widget.state.width}',
      hintText: '1–4096',
    );
    if (text == null) return;
    widget.actions.tryUpdateCustomWidth(text);
  }

  /// 自定义高度:弹输入框(校验在控制器 tryUpdateCustomHeight)。
  Future<void> _customHeight() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义高度',
      initialValue: '${widget.state.height}',
      hintText: '1–4096',
    );
    if (text == null) return;
    widget.actions.tryUpdateCustomHeight(text);
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
    widget.actions.tryUpdateCustomScaleMultiplier(text);
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
            focusNode: _loopFocusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '0 = 无限循环',
              border: _inputBorder,
            ),
            onChanged: (_) => _loopFocused = true,
            onTap: () => _loopFocused = true,
            onSubmitted: (text) {
              _loopFocused = false;
              _submitLoopText(text);
            },
          ),
        ),
        ParamRow(
          label: '速度',
          child: ParamDropdownField<double>(
            value: state.playbackSpeed,
            items: [
              // 0.25/0.5 慢放、1 正常、≥2 加速
              for (final s in _speedOptions)
                ParamDropdownItem(
                  s,
                  '${s == s.roundToDouble() ? s.toInt() : s} 倍',
                ),
            ],
            onChanged: actions.updatePlaybackSpeed,
          ),
        ),
        const SizedBox(height: 12),
        const SectionLabel('时间'),
        ParamRow(
          label: '开始',
          child: TextField(
            controller: _startCtrl,
            focusNode: _startFocusNode,
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
            focusNode: _endFocusNode,
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

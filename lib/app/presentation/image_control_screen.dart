import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/per_image_control.dart';
import '../../features/converter/application/control_target.dart';
import '../../features/export/application/scale_multiplier.dart';
import '../../features/export/presentation/custom_value_dialog.dart';
import '../../features/export/presentation/param_dropdown_field.dart';
import '../application/image_control_controller.dart';
import 'batch_parameter_form.dart' show ParamRow, SectionLabel;

/// 单张图片的精细化控制页(齿轮入口 → 全屏路由页,docs/10 UI 精细控制)。
///
/// 样式与"导入 MP4 预览工作台"一致(左预览右参数双栏),**无播放进度条
/// 无时间轴**;图片随控制实时变化(静态 Image.file 在画布比例框内按
/// [controlTarget] 呈现最终效果,透明区域以深色棋盘底示意)。
///
/// 参数:等比缩放倍数(默认 1)/ 宽度(默认 0 = 该图自身比例)/
/// 高度(默认 0);保存 → `Navigator.pop` 返回 [PerImageControl](null =
/// 未保存);恢复默认 → 重置 (1, 0, 0)。
/// 语义:双边指定 = 遵守用户决定允许变形;仅倍率/单边 = 等比不扭曲;
/// 宽高均 0 时倍数生效,否则倍数忽略(页面提示文案注明)。
class ImageControlScreen extends ConsumerStatefulWidget {
  const ImageControlScreen({
    super.key,
    required this.path,
    required this.index,
    required this.canvasW,
    required this.canvasH,
    required this.initial,
  });

  /// 图片路径(extra 恢复缺失时为空串 → 页面禁用)
  final String path;

  /// 图片序号(标题展示"第 N 张";extra 恢复缺失时 -1)
  final int index;

  /// 统一画布尺寸(0 = 未知,预览退化为图片自身比例)
  final int canvasW;
  final int canvasH;

  /// 该图当前控制(可空 = 未操作)
  final PerImageControl? initial;

  @override
  ConsumerState<ImageControlScreen> createState() => _ImageControlScreenState();
}

class _ImageControlScreenState extends ConsumerState<ImageControlScreen> {
  static const _sizeOptions = [
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
  void initState() {
    super.initState();
    // 延迟到首帧后初始化:避免 initState 内触发 Notifier 状态写入;
    // 播种 + 源尺寸探测都在控制器(image_control_controller)
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(imageControlControllerProvider.notifier)
          .init(
            path: widget.path,
            canvasW: widget.canvasW,
            canvasH: widget.canvasH,
            initial: widget.initial,
          );
    });
  }

  /// 弹 SnackBar(自定义输入是模态弹窗,页面红字不可见,SnackBar 为
  /// 正确反馈载体;解析/校验/文案在控制器,UI 只呈现)。
  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 保存:校验(控制器 validateSave)→ pop 返回 [PerImageControl]。
  void _save() {
    final notifier = ref.read(imageControlControllerProvider.notifier);
    final err = notifier.validateSave();
    if (err != null) {
      _snack(err);
      return;
    }
    Navigator.pop(context, ref.read(imageControlControllerProvider).control);
  }

  void _reset() {
    ref.read(imageControlControllerProvider.notifier).reset();
  }

  Future<void> _customMultiplier() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义缩放倍数',
      initialValue: '${ref.read(imageControlControllerProvider).multiplier}',
      hintText: '0.1–4',
    );
    if (text == null || !mounted) return;
    final err = ref
        .read(imageControlControllerProvider.notifier)
        .tryUpdateCustomScaleMultiplier(text);
    if (err != null) _snack(err);
  }

  Future<void> _customWidth() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义宽度',
      initialValue: '${ref.read(imageControlControllerProvider).width}',
      hintText: '1–4096',
    );
    if (text == null || !mounted) return;
    final err = ref
        .read(imageControlControllerProvider.notifier)
        .tryUpdateCustomWidth(text);
    if (err != null) _snack(err);
  }

  Future<void> _customHeight() async {
    final text = await showCustomValueDialog(
      context,
      title: '自定义高度',
      initialValue: '${ref.read(imageControlControllerProvider).height}',
      hintText: '1–4096',
    );
    if (text == null || !mounted) return;
    final err = ref
        .read(imageControlControllerProvider.notifier)
        .tryUpdateCustomHeight(text);
    if (err != null) _snack(err);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageControlControllerProvider);
    final notifier = ref.read(imageControlControllerProvider.notifier);
    final sourceSize = state.sourceSize;
    final hasCanvas = state.hasCanvas;
    // 最终呈现尺寸(预览用;源尺寸未知 → null 退化为原图 contain)
    final target = hasCanvas && sourceSize != null
        ? controlTarget(
            control: state.control,
            sourceWidth: sourceSize.width,
            sourceHeight: sourceSize.height,
            canvasWidth: widget.canvasW,
            canvasHeight: widget.canvasH,
          )
        : null;

    final preview = hasCanvas
        ? AspectRatio(
            aspectRatio: widget.canvasW / widget.canvasH,
            child: _CanvasPreview(
              path: widget.path,
              target: target,
              canvasW: widget.canvasW,
              canvasH: widget.canvasH,
            ),
          )
        : Center(
            child: Image.file(
              File(widget.path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image, size: 64),
            ),
          );

    final invalid = widget.path.isEmpty || state.probeFailed;
    final formPanel = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('该图参数'),
          ParamRow(
            label: '缩放倍率',
            child: ParamDropdownField<double?>(
              value:
                  state.multiplier == 1.0 &&
                      state.width == 0 &&
                      state.height == 0
                  ? 1.0
                  : state.multiplier,
              enabled: !invalid,
              items: [
                for (final m in kScaleMultiplierOptions)
                  ParamDropdownItem<double?>(
                    m,
                    '${m == m.roundToDouble() ? m.toInt() : m} 倍',
                  ),
                const ParamDropdownItem<double?>(null, '自定义'),
              ],
              valueLabelBuilder: (v) {
                if (v == null) return '自定义';
                return '${v == v.roundToDouble() ? v.toInt() : v} 倍';
              },
              onChanged: (m) {
                if (m == null) {
                  _customMultiplier();
                  return;
                }
                notifier.updateMultiplier(m);
              },
            ),
          ),
          ParamRow(
            label: '宽度',
            child: ParamDropdownField<int>(
              value: state.width,
              enabled: !invalid,
              items: [
                for (final w in _sizeOptions)
                  ParamDropdownItem(w, w == 0 ? '原图等比' : '$w px'),
                const ParamDropdownItem(-1, '自定义'),
              ],
              valueLabelBuilder: (w) => w == 0 ? '原图等比' : '$w px',
              onChanged: (w) {
                if (w == -1) {
                  _customWidth();
                  return;
                }
                notifier.updateWidth(w);
              },
            ),
          ),
          ParamRow(
            label: '高度',
            child: ParamDropdownField<int>(
              value: state.height,
              enabled: !invalid,
              items: [
                for (final h in _sizeOptions)
                  ParamDropdownItem(h, h == 0 ? '原图等比' : '$h px'),
                const ParamDropdownItem(-1, '自定义'),
              ],
              valueLabelBuilder: (h) => h == 0 ? '原图等比' : '$h px',
              onChanged: (h) {
                if (h == -1) {
                  _customHeight();
                  return;
                }
                notifier.updateHeight(h);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '宽度与高度均指定时按精确尺寸(允许变形);'
              '仅倍率或单边保持该图比例。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (sourceSize != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '源图 ${sourceSize.width}×${sourceSize.height}'
                '${target != null ? ' · 画布内呈现 ${target.width}×${target.height}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (invalid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '无法读取图片,已禁用编辑',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: invalid ? null : _reset,
                child: const Text('恢复默认'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: invalid ? null : _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.index >= 0 ? '精细化控制 · 第 ${widget.index + 1} 张' : '精细化控制',
        ),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                Expanded(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: preview),
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: SafeArea(
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Column(children: [formPanel]),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: preview),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(child: SafeArea(child: formPanel)),
            ],
          );
        },
      ),
    );
  }
}

/// 画布比例框内的最终呈现预览(深色棋盘底示意透明 pad 区)。
///
/// [target] 为 [controlTarget] 计算结果(画布内呈现尺寸);图片按目标
/// 比例 fill,空余区域即 pad 区(透明);[target] 为 null(源尺寸未知)
/// 时原图 contain 于画布框。
class _CanvasPreview extends StatelessWidget {
  const _CanvasPreview({
    required this.path,
    required this.target,
    required this.canvasW,
    required this.canvasH,
  });

  final String path;
  final ({int width, int height})? target;
  final int canvasW;
  final int canvasH;

  @override
  Widget build(BuildContext context) {
    final t = target;
    return LayoutBuilder(
      builder: (context, c) {
        final image = Image.file(
          File(path),
          fit: t == null ? BoxFit.contain : BoxFit.fill,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48),
        );
        if (t == null) {
          // 源尺寸未知:无呈现尺寸可算,原图 contain 于画布框
          return _Checkerboard(child: Center(child: image));
        }
        return _Checkerboard(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: t.width / canvasW,
              heightFactor: t.height / canvasH,
              child: image,
            ),
          ),
        );
      },
    );
  }
}

/// 深色棋盘格底(示意透明区域;桌面端透明在截图/背景色下不可见)。
class _Checkerboard extends StatelessWidget {
  const _Checkerboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

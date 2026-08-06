import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 参数下拉字段(P7 设计稿,docs/10 §10.3.1):M3 风格下拉选择。
///
/// 收起态与同面板 TextField 视觉统一(OutlinedInputBorder 圆角 8,
/// isDense 紧凑)。展开态为**自绘 Overlay 菜单**(弃用 MenuAnchor:
/// 其 _MenuLayout 在下方空间不足时会把菜单翻转到按钮上方,实测
/// 真机参数面板位于窗口下部时始终向上弹出,与"下拉"诉求相悖)。
///
/// 自绘菜单特性:
/// - **固定下拉**:菜单顶部紧贴按钮底部,永不翻转;
/// - **高度自适应**:下方空间不足时压缩菜单高度(内部滚动),不超出屏幕;
/// - **与按钮同宽左对齐**;圆角 8 / elevation 2 / surfaceContainerHighest;
/// - 选中项 primary 高亮 + 勾选图标;点击外部关闭;disabled 灰显禁点。
class ParamDropdownField<T> extends StatefulWidget {
  const ParamDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.valueLabelBuilder,
    this.labelOverride,
  });

  /// 当前选中值(收起态显示其 label)。
  final T value;

  /// 候选列表(选中值必须出现在 [items] 中,否则取首项展示)。
  final List<ParamDropdownItem<T>> items;

  /// 选择回调(点击菜单项触发,菜单自动收起)。
  final ValueChanged<T> onChanged;

  /// 禁用态:灰显且不可展开(面板锁定/转码中)。
  final bool enabled;

  /// 选中值不在 [items] 中时的收起态文案构造器(如"自定义"回显)。
  /// 为 null 时保持原行为(取 [items] 首项展示)。
  final String Function(T value)? valueLabelBuilder;

  /// 收起态文案覆盖(优先级最高;菜单项/勾选逻辑不受影响)。
  /// 用于选中值仍在 [items] 内、但需按联动状态换文案的场景
  /// (如批量设置页选倍数后宽高显示"原图等比 0.75")。
  final String? labelOverride;

  @override
  State<ParamDropdownField<T>> createState() => _ParamDropdownFieldState<T>();
}

class _ParamDropdownFieldState<T> extends State<ParamDropdownField<T>> {
  final _anchorKey = GlobalKey();
  OverlayEntry? _menuEntry;

  String get _label {
    final override = widget.labelOverride;
    if (override != null) return override;
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    final builder = widget.valueLabelBuilder;
    if (builder != null) return builder(widget.value);
    return widget.items.first.label;
  }

  @override
  void dispose() {
    _menuEntry?.remove();
    super.dispose();
  }

  void _toggle() {
    if (_menuEntry != null) {
      _close();
      return;
    }
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    final overlay = Overlay.of(context);
    _menuEntry = OverlayEntry(builder: (_) => _buildMenu(anchorRect));
    overlay.insert(_menuEntry!);
  }

  void _close() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  /// 菜单:Stack(透明点击拦截层 + 按钮正下方的定位菜单)。
  Widget _buildMenu(Rect anchorRect) {
    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    // 下方可用高度(按钮底到屏幕底,留 8px 边距);按钮接近窗口底部时
    // 该值会 ≤0,钳制到至少 2 项高度(88px),不足部分菜单内部滚动
    final maxHeight = math.max(88.0, screenSize.height - anchorRect.bottom - 8);

    return Stack(
      children: [
        // 点击外部关闭(透明拦截层,覆盖全屏)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: anchorRect.left,
          top: anchorRect.bottom,
          width: anchorRect.width,
          child: Material(
            elevation: 2,
            color: scheme.surfaceContainerHighest,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final item in widget.items) _buildItem(item, scheme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(ParamDropdownItem<T> item, ColorScheme scheme) {
    final selected = item.value == widget.value;
    return InkWell(
      onTap: () {
        widget.onChanged(item.value);
        _close();
      },
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              selected
                  ? Icon(Icons.check, size: 18, color: scheme.primary)
                  : const SizedBox(width: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: selected
                      ? TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    return InkWell(
      key: _anchorKey,
      onTap: widget.enabled ? _toggle : null,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: InputDecorator(
        decoration: InputDecoration(
          enabled: widget.enabled,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: widget.enabled ? null : disabledColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// 下拉候选项(值 + 展示文案)。
class ParamDropdownItem<T> {
  const ParamDropdownItem(this.value, this.label);

  final T value;
  final String label;
}

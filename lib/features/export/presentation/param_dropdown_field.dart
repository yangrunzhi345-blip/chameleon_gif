import 'package:flutter/material.dart';

/// 参数下拉字段(P7 设计稿,docs/10 §10.3.1):M3 风格下拉选择。
///
/// 收起态与同面板 TextField 视觉统一(OutlinedInputBorder 圆角 8,
/// isDense 紧凑);展开态为 M3 弹出菜单(elevation 2 / 圆角 8 /
/// surfaceContainerHighest 背景 / 与按钮同宽对齐)。选中项在菜单内
/// 以 primary 高亮 + 勾选图标标记;`enabled=false` 整组灰显禁点。
class ParamDropdownField<T> extends StatefulWidget {
  const ParamDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  /// 当前选中值(收起态显示其 label)。
  final T value;

  /// 候选列表(选中值必须出现在 [items] 中,否则取首项展示)。
  final List<ParamDropdownItem<T>> items;

  /// 选择回调(点击菜单项触发,菜单自动收起)。
  final ValueChanged<T> onChanged;

  /// 禁用态:灰显且不可展开(面板锁定/转码中)。
  final bool enabled;

  @override
  State<ParamDropdownField<T>> createState() => _ParamDropdownFieldState<T>();
}

class _ParamDropdownFieldState<T> extends State<ParamDropdownField<T>> {
  final _menuController = MenuController();

  String get _label {
    return widget.items
        .firstWhere(
          (e) => e.value == widget.value,
          orElse: () => widget.items.first,
        )
        .label;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabledColor = Theme.of(context).disabledColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _menuController,
          // 关闭交叉轴解约束:菜单宽度受 effectiveConstraints 约束
          // (否则 IntrinsicWidth + UnconstrainedBox 让菜单按内容收缩,
          // 锁宽失效,实测菜单 152px vs 按钮 800px)
          crossAxisUnconstrained: false,
          style: MenuStyle(
            elevation: const WidgetStatePropertyAll(2),
            backgroundColor: WidgetStatePropertyAll(
              scheme.surfaceContainerHighest,
            ),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            // standard density:避免桌面 compact 对菜单约束压缩
            // (实测 compact 下面板 784 vs 按钮 800,差 16)
            visualDensity: VisualDensity.standard,
          ),
          builder: (context, controller, child) {
            return InkWell(
              onTap: widget.enabled
                  ? () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        // 强制下拉:菜单左上角 = 按钮左下角(避免空间不足
                        // 时 MenuStyle.alignment 自动翻转成向上弹出)
                        final box = context.findRenderObject() as RenderBox?;
                        controller.open(
                          position: Offset(0, box?.size.height ?? 0),
                        );
                      }
                    }
                  : null,
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
          },
          menuChildren: [
            for (final item in widget.items)
              // 菜单项固定宽 = 按钮宽:菜单面板(IntrinsicWidth)固有宽即
              // 按钮宽,与按钮左对齐完全一致
              SizedBox(
                width: width,
                child: MenuItemButton(
                  onPressed: () {
                    widget.onChanged(item.value);
                    _menuController.close();
                  },
                  leadingIcon: item.value == widget.value
                      ? Icon(Icons.check, size: 18, color: scheme.primary)
                      : const SizedBox(width: 18),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: item.value == widget.value
                        ? TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 下拉候选项(值 + 展示文案)。
class ParamDropdownItem<T> {
  const ParamDropdownItem(this.value, this.label);

  final T value;
  final String label;
}

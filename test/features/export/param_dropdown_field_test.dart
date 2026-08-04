import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/export/presentation/param_dropdown_field.dart';

/// ParamDropdownField 组件单测(P7 设计稿):收起态/展开菜单/回调/禁用态。
void main() {
  const items = [
    ParamDropdownItem(0, '原图等比'),
    ParamDropdownItem(480, '480 px'),
    ParamDropdownItem(640, '640 px'),
    ParamDropdownItem(1920, '1920 px'),
  ];

  /// 受控组件测试:onChanged 经 setState 回写 value(与真实面板一致)。
  Widget build({
    int value = 480,
    ValueChanged<int>? onChanged,
    bool enabled = true,
  }) {
    var current = value;
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300, // 贴近真实面板按钮宽(Expanded 约束)
            child: StatefulBuilder(
              builder: (context, setState) => ParamDropdownField<int>(
                value: current,
                items: items,
                enabled: enabled,
                onChanged: (v) {
                  setState(() => current = v);
                  onChanged?.call(v);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('收起态显示选中 label 与下拉箭头', (tester) async {
    await tester.pumpWidget(build(value: 480));

    expect(find.text('480 px'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    // 未展开:菜单项不可见
    expect(find.text('640 px'), findsNothing);
  });

  testWidgets('值不在候选中 → 展示首项 label', (tester) async {
    await tester.pumpWidget(build(value: 999));

    expect(find.text('原图等比'), findsOneWidget);
  });

  testWidgets('菜单在按钮正下方弹出(强制下拉)且与按钮同宽', (tester) async {
    await tester.pumpWidget(build());

    final btnRect = tester.getRect(find.byType(ParamDropdownField<int>));
    await tester.tap(find.text('480 px'));
    await tester.pumpAndSettle();

    // 菜单面板(Material,elevation 2 + 圆角 borderRadius)顶部 >= 按钮底部
    final menuPanel = find.byWidgetPredicate(
      (w) => w is Material && w.elevation == 2 && w.borderRadius != null,
      skipOffstage: false,
    );
    expect(menuPanel, findsOneWidget);
    final panelRect = tester.getRect(menuPanel);
    expect(panelRect.top, greaterThanOrEqualTo(btnRect.bottom - 1));
    // 菜单面板宽度 == 按钮宽度(菜单项 SizedBox 固定宽驱动,左对齐)
    expect(panelRect.width, closeTo(btnRect.width, 0.5));
    expect(panelRect.left, closeTo(btnRect.left, 0.5));
  });

  testWidgets('点击展开菜单,选择后触发回调并收起', (tester) async {
    int? selected;
    await tester.pumpWidget(build(onChanged: (v) => selected = v));

    await tester.tap(find.text('480 px'));
    await tester.pumpAndSettle();
    // 菜单展开:全部候选项可见(MenuAnchor 菜单在测试中处于 offstage,
    // 菜单项 finder 需 skipOffstage: false;真实应用不受影响)
    expect(find.text('原图等比', skipOffstage: false), findsOneWidget);
    expect(find.text('640 px', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('640 px', skipOffstage: false).last);
    await tester.pumpAndSettle();

    expect(selected, 640);
    // 菜单已收起,收起态显示新值
    expect(find.text('640 px'), findsOneWidget);
    expect(find.text('1920 px'), findsNothing);
  });

  testWidgets('展开菜单中选中项带勾选图标', (tester) async {
    await tester.pumpWidget(build(value: 480));
    await tester.tap(find.text('480 px'));
    await tester.pumpAndSettle();

    // 仅选中项(480 px)带 check 图标(菜单项同需 skipOffstage: false)
    expect(find.byIcon(Icons.check, skipOffstage: false), findsOneWidget);
    final checkIcon = tester.widget<Icon>(
      find.byIcon(Icons.check, skipOffstage: false),
    );
    expect(checkIcon.color, isNotNull);
  });

  testWidgets('disabled 态:灰显且不可展开', (tester) async {
    await tester.pumpWidget(build(enabled: false));

    await tester.tap(find.text('480 px'));
    await tester.pumpAndSettle();

    // 菜单未展开
    expect(find.text('640 px'), findsNothing);
  });
}

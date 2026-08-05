import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';

/// 首页布局回归:品牌区(Logo/标题/标语)与按钮区均以屏幕中线水平居中
/// (真机曾出现 body 内容整体偏左 273px 的渲染异常,测试锁定代码层布局)。
void main() {
  testWidgets('品牌区与按钮区均水平居中(中线对齐)', (tester) async {
    tester.view.physicalSize = const Size(1260, 2800);
    tester.view.devicePixelRatio = 3.0; // 对齐 vivo 真机分辨率
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );
    await tester.pump();

    final screenCenter = tester.view.physicalSize.width / 2 / 3.0;
    double centerXOf(Finder finder) {
      final box = tester.renderObject<RenderBox>(finder);
      return box.localToGlobal(Offset.zero).dx + box.size.width / 2;
    }

    // body 内文本:28px 加粗的是 body 标题(AppBar 标题是 20px 常规),
    // 排除同名 AppBar 标题
    final bodyTitle = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == 'Chameleon Gif' &&
          (w.style?.fontSize ?? 0) >= 28,
    );

    expect(centerXOf(bodyTitle), closeTo(screenCenter, 1.0),
        reason: '标题以屏幕中线对齐');
    expect(
      centerXOf(find.text('基础架构就绪')),
      closeTo(screenCenter, 1.0),
      reason: '标语以屏幕中线对齐',
    );

    final btnBox = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('导入 MP4'),
        matching: find.byType(FilledButton),
      ),
    );
    final btnCenter =
        btnBox.localToGlobal(Offset.zero).dx + btnBox.size.width / 2;
    expect(btnCenter, closeTo(screenCenter, 1.0), reason: '按钮以屏幕中线对齐');
  });
}

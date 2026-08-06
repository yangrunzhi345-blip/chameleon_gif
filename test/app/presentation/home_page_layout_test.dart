import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_screen_recorder_port.dart';

/// 首页布局回归:品牌区(Logo/标题/标语)与按钮区均以屏幕中线水平居中
/// (真机曾出现 body 内容整体偏左 273px 的渲染异常,测试锁定代码层布局)。
///
/// 采集入口能力探测经端口 provider(无注入时默认抛错),测试注入
/// fake 端口(fake 枚举非空/能力可用,入口常亮,不影响布局断言)。
void main() {
  Widget buildHome() {
    return ProviderScope(
      overrides: [
        cameraPortProvider.overrideWithValue(FakeCameraPort()),
        screenRecorderPortProvider.overrideWithValue(FakeScreenRecorderPort()),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  testWidgets('品牌区与按钮区均水平居中(中线对齐)', (tester) async {
    tester.view.physicalSize = const Size(1260, 2800);
    tester.view.devicePixelRatio = 3.0; // 对齐 vivo 真机分辨率
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildHome());
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

    expect(
      centerXOf(bodyTitle),
      closeTo(screenCenter, 1.0),
      reason: '标题以屏幕中线对齐',
    );
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

  testWidgets('图片制作 GIF 入口在导入 MP4 上方,同为 FilledButton', (tester) async {
    tester.view.physicalSize = const Size(1260, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildHome());
    await tester.pump();

    final gifBtn = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('图片制作 GIF'),
        matching: find.byType(FilledButton),
      ),
    );
    final mp4Btn = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('导入 MP4'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      gifBtn.localToGlobal(Offset.zero).dy,
      lessThan(mp4Btn.localToGlobal(Offset.zero).dy),
      reason: '图片制作 GIF 入口位于导入 MP4 上方',
    );
    expect(
      gifBtn.size.height,
      mp4Btn.size.height,
      reason: '同为 FilledButton 变体,高度一致(样式一致)',
    );
  });
}

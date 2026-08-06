/// 区域框选遮罩交互单测(拖拽/点按/Esc 取消、尺寸文本、背景回退)。
library;

import 'dart:convert';

import 'package:chameleon_gif/features/screen_record/application/region_picker.dart';
import 'package:chameleon_gif/features/screen_record/presentation/region_select_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 红色 PNG(解码渲染路径验证)。
final Uint8List _redPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  /// 起遮罩路由,返回 pop 结果 Future。
  ///
  /// 注意:async 函数 return Future 会被隐式 await(unwrap),故用
  /// record 包一层返回,避免 pumpOverlay 等待用户 pop 而死锁。
  Future<({Future<RegionGeometry?> result})> pumpOverlay(
    WidgetTester tester, {
    Uint8List? pngBytes,
  }) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = nav.currentState!.push<RegionGeometry>(
      MaterialPageRoute(
        builder: (_) => RegionSelectOverlay(dpr: 1, pngBytes: pngBytes),
      ),
    );
    await tester.pumpAndSettle();
    return (result: future);
  }

  testWidgets('拖拽画框 → pop 屏幕像素几何', (tester) async {
    final future = (await pumpOverlay(tester)).result;
    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(300, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final g = await future;
    expect(g, isNotNull);
    expect(g!.x, 100);
    expect(g.y, 100);
    expect(g.width, 200);
    expect(g.height, 100);
  });

  testWidgets('拖拽中实时显示尺寸文本', (tester) async {
    await pumpOverlay(tester);
    expect(find.textContaining('x'), findsNothing, reason: '拖拽前无选区文本');

    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(300, 200));
    await tester.pump();

    expect(find.text('200x100+100+100'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('点按(未拖拽)= 误触 → pop null', (tester) async {
    final future = (await pumpOverlay(tester)).result;
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Esc → pop null', (tester) async {
    final future = (await pumpOverlay(tester)).result;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('pngBytes 提供时正常渲染并拖拽', (tester) async {
    final future = (await pumpOverlay(tester, pngBytes: _redPng)).result;
    final gesture = await tester.startGesture(const Offset(50, 50));
    await tester.pump();
    await gesture.moveTo(const Offset(150, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final g = await future;
    expect(g!.width, 100);
    expect(g.height, 100);
  });
}

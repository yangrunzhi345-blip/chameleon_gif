/// 全屏截图遮罩编排器单测(FakeWindow 记录调用序列;widget 层拖拽驱动)。
library;

import 'dart:convert';
import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/features/screen_record/application/record_command_builder.dart'
    show RecordCommandKind;
import 'package:chameleon_gif/features/screen_record/presentation/overlay_region_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 红色 PNG(截图字节)。
final Uint8List _redPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// 记录调用序列的 fake 窗口(全屏矩形 800×600)。
class _FakeWindow implements OverlayWindowController {
  final List<String> calls = [];
  bool fullScreen = false;
  bool maximized = false;
  bool throwOnSetFullScreen = false;

  /// 全屏矩形(逻辑,窗口所在显示器)。
  final Rect bounds = const Rect.fromLTWH(0, 0, 800, 600);

  @override
  Future<Rect> getBounds() async {
    calls.add('getBounds');
    return bounds;
  }

  @override
  Future<void> setBounds(Rect bounds) async {
    calls.add('setBounds');
  }

  @override
  Future<void> hide() async {
    calls.add('hide');
  }

  @override
  Future<void> show() async {
    calls.add('show');
  }

  @override
  Future<void> focus() async {
    calls.add('focus');
  }

  @override
  Future<void> setFullScreen(bool v) async {
    calls.add('setFullScreen($v)');
    if (v && throwOnSetFullScreen) {
      throw Exception('simulated failure');
    }
    fullScreen = v;
  }

  @override
  Future<bool> isFullScreen() async {
    calls.add('isFullScreen');
    return fullScreen;
  }

  @override
  Future<void> setAlwaysOnTop(bool v) async {
    calls.add('setAlwaysOnTop($v)');
  }

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized');
    return maximized;
  }
}

void main() {
  late _FakeWindow window;
  late List<String> captureArgs;
  late Uint8List? captureResult;

  OverlayRegionPicker buildPicker(
    GlobalKey<NavigatorState> nav, {
    double dpr = 1,
    RecordCommandKind kind = RecordCommandKind.x11grab,
  }) {
    return OverlayRegionPicker(
      navigatorKey: nav,
      tempDir: Directory.systemTemp,
      kind: kind,
      display: ':0',
      logger: AppLogger(),
      windowController: window,
      captureRunner: (args) async {
        captureArgs = args;
        return captureResult;
      },
      devicePixelRatio: () => dpr,
      settleDelay: Duration.zero,
    );
  }

  /// 在遮罩上拖拽 (100,100) → (300,200)。
  Future<void> dragSelect(WidgetTester tester) async {
    final gesture = await tester.startGesture(const Offset(100, 100));
    await tester.pump();
    await gesture.moveTo(const Offset(300, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  setUp(() {
    window = _FakeWindow();
    captureArgs = [];
    captureResult = _redPng;
  });

  testWidgets('完整流程:拖拽确认返回几何,窗口调用序列含恢复', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav).pick();
    await tester.pumpAndSettle();
    await dragSelect(tester);

    final g = await future;
    expect(g, isNotNull);
    expect(g!.x, 100);
    expect(g.y, 100);
    expect(g.width, 200);
    expect(g.height, 100);
    // 截图参数:全屏 800×600(dpr 1),x11grab 分支
    expect(
      captureArgs,
      containsAllInOrder([
        '-f',
        'x11grab',
        '-video_size',
        '800x600',
        '-i',
        ':0+0+0',
        '-frames:v',
        '1',
      ]),
    );
    // 窗口调用序列(前置 + 遮罩期 + finally 恢复)
    expect(window.calls, [
      'getBounds',
      'isMaximized',
      'setAlwaysOnTop(true)',
      'setFullScreen(true)',
      'isFullScreen',
      'getBounds',
      'hide',
      'show',
      'focus',
      'isFullScreen',
      'setFullScreen(false)',
      'isFullScreen',
      'setAlwaysOnTop(false)',
      'setBounds',
    ]);
  });

  testWidgets('Esc 取消 → null,窗口恢复完成', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav).pick();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(await future, isNull);
    expect(window.calls.last, 'setBounds', reason: 'finally 恢复已执行');
  });

  testWidgets('截图失败 → 纯色遮罩仍返回几何', (tester) async {
    captureResult = null;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav).pick();
    await tester.pumpAndSettle();
    await dragSelect(tester);

    expect(await future, isNotNull);
  });

  testWidgets('窗口操作异常 → null,恢复仍执行', (tester) async {
    window.throwOnSetFullScreen = true;
    final nav = GlobalKey<NavigatorState>();
    // 未挂载 MaterialApp:若窗口流程未抛异常,navigator null 也会返回 null;
    // 此处验证异常路径提前返回且恢复执行。
    final g = await buildPicker(nav).pick();
    expect(g, isNull);
    expect(window.calls, [
      'getBounds',
      'isMaximized',
      'setAlwaysOnTop(true)',
      'setFullScreen(true)', // ← 抛异常,提前返回
      'setFullScreen(false)',
      'isFullScreen',
      'setAlwaysOnTop(false)',
      'setBounds',
    ]);
  });

  testWidgets('最大化窗口恢复时不 setBounds', (tester) async {
    window.maximized = true;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav).pick();
    await tester.pumpAndSettle();
    await dragSelect(tester);

    expect(await future, isNotNull);
    expect(window.calls, isNot(contains('setBounds')));
  });

  testWidgets('导航器未就绪 → null', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    // 无 widget 树:settleDelay 的 Future.delayed 在假时钟下需外部驱动,
    // 用 runAsync(真实时钟)使 pick 独立完成;本用例不涉 widget 交互。
    final g = await tester.runAsync(() => buildPicker(nav).pick());
    expect(g, isNull);
    expect(window.calls, contains('hide'), reason: '窗口流程已走到遮罩前');
  });

  testWidgets('DPR 2.0 → 截图参数为物理像素', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav, dpr: 2).pick();
    await tester.pumpAndSettle();
    await dragSelect(tester);

    expect(await future, isNotNull);
    expect(
      captureArgs,
      containsAllInOrder(['-video_size', '1600x1200', '-i', ':0+0+0']),
    );
  });

  testWidgets('gdigrab 分支截图参数', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const SizedBox()),
    );
    final future = buildPicker(nav, kind: RecordCommandKind.gdigrab).pick();
    await tester.pumpAndSettle();
    await dragSelect(tester);

    expect(await future, isNotNull);
    expect(
      captureArgs,
      containsAllInOrder([
        '-f',
        'gdigrab',
        '-offset_x',
        '0',
        '-offset_y',
        '0',
        '-video_size',
        '800x600',
        '-i',
        'desktop',
      ]),
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/presentation/image_control_screen.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/value_objects/per_image_control.dart';
import 'package:chameleon_gif/features/import/application/import_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_image_probe_port.dart';

/// 精细化控制页测试:渲染/编辑/保存返回/恢复默认/探测失败禁用。
void main() {
  late FakeImageProbePort probe;

  setUp(() {
    probe = FakeImageProbePort(width: 640, height: 480);
  });

  /// 宿主:按钮 push 控制页,保存结果写回 [result]。
  (Widget, ValueNotifier<PerImageControl?>) buildHost({
    PerImageControl? initial,
    int canvasW = 640,
    int canvasH = 480,
  }) {
    final result = ValueNotifier<PerImageControl?>(null);
    final host = ProviderScope(
      overrides: [
        imageProbePortProvider.overrideWithValue(probe),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result.value = await Navigator.push<PerImageControl>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageControlScreen(
                        path: '/img/a.png',
                        index: 0,
                        canvasW: canvasW,
                        canvasH: canvasH,
                        initial: initial,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    return (host, result);
  }

  Future<void> open(WidgetTester tester, Widget host) async {
    // 宽视口:下拉菜单(自绘 Overlay,高度自适应)完整展开,避免窄屏
    // 菜单被压缩后高序选项滚出视口导致 tap miss(组件设计为可滚动,
    // 真机可滚动选择,测试选大视口聚焦交互语义)
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('渲染:标题/三参数下拉(默认值)/保存与恢复默认', (tester) async {
    final (host, _) = buildHost();
    await open(tester, host);

    expect(find.text('精细化控制 · 第 1 张'), findsOneWidget);
    expect(find.text('缩放倍率'), findsOneWidget);
    expect(find.text('宽度'), findsOneWidget);
    expect(find.text('高度'), findsOneWidget);
    // 默认值:1 倍 / 原图等比 ×2
    expect(find.text('1 倍'), findsOneWidget);
    expect(find.text('原图等比'), findsNWidgets(2));
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    // 预览:图片在画布比例框内
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('源图 640×480'), findsOneWidget);
  });

  testWidgets('选 2 倍 → 保存 → pop 返回 PerImageControl(倍率 2)', (tester) async {
    final (host, result) = buildHost();
    await open(tester, host);

    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result.value, const PerImageControl(scaleMultiplier: 2.0));
    expect(find.byType(ImageControlScreen), findsNothing, reason: '保存后返回');
  });

  testWidgets('自定义宽度 → 保存 → 返回(宽 480,倍率保持 1)', (tester) async {
    final (host, result) = buildHost();
    await open(tester, host);

    await tester.tap(find.text('原图等比').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '480',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(result.value, const PerImageControl(width: 480));
  });

  testWidgets('恢复默认:设置后重置 (1, 0, 0) 再保存', (tester) async {
    final (host, result) = buildHost(
      initial: const PerImageControl(width: 480),
    );
    await open(tester, host);

    // 初始回显 480 px
    expect(find.text('480 px'), findsOneWidget);

    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    expect(find.text('原图等比'), findsNWidgets(2), reason: '宽高回默认');
    expect(find.text('1 倍'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result.value, const PerImageControl(), reason: '恢复默认后保存 = 未操作');
  });

  testWidgets('初始控制回显:传入 (1.5, 0, 0) → 收起态 1.5 倍', (tester) async {
    final (host, _) = buildHost(
      initial: const PerImageControl(scaleMultiplier: 1.5),
    );
    await open(tester, host);

    expect(find.text('1.5 倍'), findsOneWidget);
  });

  testWidgets('探测失败 → 提示并禁用保存/恢复默认/控件', (tester) async {
    probe.error = StateError('decode failed');
    final (host, result) = buildHost();
    await open(tester, host);

    expect(find.text('无法读取图片,已禁用编辑'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.ancestor(of: find.text('保存'), matching: find.byType(FilledButton)),
    );
    expect(save.onPressed, isNull, reason: '探测失败禁保存');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result.value, isNull, reason: '禁用的保存不返回结果');
  });

  testWidgets('画布未知(canvas 0):预览退化,控件仍可用', (tester) async {
    final (host, result) = buildHost(canvasW: 0, canvasH: 0);
    await open(tester, host);

    expect(find.byType(Image), findsOneWidget);
    // 无画布时源尺寸仅展示,不计算呈现尺寸
    expect(find.textContaining('画布内呈现'), findsNothing);
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5 倍').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result.value, const PerImageControl(scaleMultiplier: 0.5));
  });
}

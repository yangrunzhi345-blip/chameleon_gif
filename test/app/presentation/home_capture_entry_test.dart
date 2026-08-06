import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/presentation/home_page.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_screen_recorder_port.dart';

/// 首页采集入口能力态(置灰不隐藏,docs/18 §五):相机按设备枚举、
/// 录屏按能力探测驱动;loading 按禁用渲染(防闪亮)。
void main() {
  Widget buildHome({
    required FakeCameraPort camera,
    required FakeScreenRecorderPort recorder,
  }) {
    return ProviderScope(
      overrides: [
        cameraPortProvider.overrideWithValue(camera),
        screenRecorderPortProvider.overrideWithValue(recorder),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  /// 取入口按钮(禁用 = onPressed null)。
  FilledButton buttonOf(WidgetTester tester, String label) {
    return tester.widget<FilledButton>(
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
    );
  }

  testWidgets('有摄像头 + 录屏可用 → 两个入口常亮', (tester) async {
    await tester.pumpWidget(
      buildHome(
        camera: FakeCameraPort(
          devices: const [
            CameraDevice(id: '/dev/video0', name: 'WebCam (/dev/video0)'),
          ],
        ),
        recorder: FakeScreenRecorderPort(
          capabilities: const RecordCapabilities(screenCaptureAvailable: true),
        ),
      ),
    );
    await tester.pump(); // 等异步探测完成
    expect(buttonOf(tester, '相机拍摄').onPressed, isNotNull);
    expect(buttonOf(tester, '屏幕录制').onPressed, isNotNull);
  });

  testWidgets('无摄像头 → 相机入口置灰 + tooltip', (tester) async {
    await tester.pumpWidget(
      buildHome(
        camera: FakeCameraPort(devices: const []),
        recorder: FakeScreenRecorderPort(),
      ),
    );
    await tester.pump();
    expect(buttonOf(tester, '相机拍摄').onPressed, isNull);
    expect(find.byTooltip('未检测到摄像头'), findsOneWidget);
  });

  testWidgets('录屏不可用 → 置灰 + hint tooltip,相机不受影响', (tester) async {
    await tester.pumpWidget(
      buildHome(
        camera: FakeCameraPort(),
        recorder: FakeScreenRecorderPort(
          capabilities: const RecordCapabilities(
            screenCaptureAvailable: false,
            hint: '当前 Wayland 会话缺少屏幕共享支持',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(buttonOf(tester, '相机拍摄').onPressed, isNotNull);
    expect(buttonOf(tester, '屏幕录制').onPressed, isNull);
    expect(find.byTooltip('当前 Wayland 会话缺少屏幕共享支持'), findsOneWidget);
  });

  testWidgets('探测未完成(loading)→ 按禁用渲染,完成后自动刷新', (tester) async {
    await tester.pumpWidget(
      buildHome(camera: FakeCameraPort(), recorder: FakeScreenRecorderPort()),
    );
    // 首次帧:异步探测未决 → 入口按禁用渲染(防闪亮)
    expect(buttonOf(tester, '相机拍摄').onPressed, isNull);
    expect(buttonOf(tester, '屏幕录制').onPressed, isNull);
    // 探测完成自动刷新
    await tester.pump();
    expect(buttonOf(tester, '相机拍摄').onPressed, isNotNull);
    expect(buttonOf(tester, '屏幕录制').onPressed, isNotNull);
  });
}

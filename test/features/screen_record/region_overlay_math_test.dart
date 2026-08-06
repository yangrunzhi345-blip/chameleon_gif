/// 区域遮罩拖拽数学与截图命令装配单测(纯 Dart,不依赖真机)。
library;

import 'dart:ui' show Offset, Rect, Size;

import 'package:chameleon_gif/features/screen_record/application/record_command_builder.dart'
    show RecordCommandKind;
import 'package:chameleon_gif/features/screen_record/application/region_overlay_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDragRegion', () {
    const size = Size(1920, 1080);

    test('正向拖拽(左上 → 右下)换算物理像素', () {
      final g = resolveDragRegion(
        start: const Offset(100, 50),
        end: const Offset(740, 530),
        logicalSize: size,
        dpr: 1,
      );
      expect(g, isNotNull);
      expect(g!.x, 100);
      expect(g.y, 50);
      expect(g.width, 640);
      expect(g.height, 480);
    });

    test('反向拖拽(右下 → 左上)归一化', () {
      final g = resolveDragRegion(
        start: const Offset(740, 530),
        end: const Offset(100, 50),
        logicalSize: size,
        dpr: 1,
      );
      expect(g!.x, 100);
      expect(g.y, 50);
      expect(g.width, 640);
      expect(g.height, 480);
    });

    test('越界拖拽钳制在屏幕内', () {
      final g = resolveDragRegion(
        start: const Offset(-50, -30),
        end: const Offset(2000, 1200),
        logicalSize: size,
        dpr: 1,
      );
      expect(g!.x, 0);
      expect(g.y, 0);
      expect(g.width, 1920);
      expect(g.height, 1080);
    });

    test('误触(两轴位移均 < 4 逻辑像素)→ null', () {
      final g = resolveDragRegion(
        start: const Offset(100, 100),
        end: const Offset(103.9, 103.9),
        logicalSize: size,
        dpr: 1,
      );
      expect(g, isNull);
    });

    test('单轴位移 ≥ 4 不算误触', () {
      final g = resolveDragRegion(
        start: const Offset(100, 100),
        end: const Offset(200, 100.5),
        logicalSize: size,
        dpr: 1,
      );
      expect(g, isNotNull);
      expect(g!.width, 100);
      expect(g.height, 1); // 最小 1px 钳制
    });

    test('DPR 2.0 物理像素取整', () {
      final g = resolveDragRegion(
        start: const Offset(10.4, 20.6),
        end: const Offset(100.6, 200.4),
        logicalSize: size,
        dpr: 2,
      );
      // 左 20.8→21;右 201.2→201;上 41.2→41;下 400.8→401
      expect(g!.x, 21);
      expect(g.y, 41);
      expect(g.width, 180);
      expect(g.height, 360);
    });
  });

  group('buildSingleFrameCaptureArgs', () {
    const rect = Rect.fromLTWH(100, 50, 640, 480);

    test('x11grab 分支参数快照', () {
      expect(
        buildSingleFrameCaptureArgs(
          physicalRect: rect,
          kind: RecordCommandKind.x11grab,
          display: ':0',
          outputPath: '/tmp/region.png',
        ),
        [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'x11grab',
          '-video_size',
          '640x480',
          '-i',
          ':0+100+50',
          '-frames:v',
          '1',
          '-y',
          '/tmp/region.png',
        ],
      );
    });

    test('gdigrab 分支参数快照', () {
      expect(
        buildSingleFrameCaptureArgs(
          physicalRect: rect,
          kind: RecordCommandKind.gdigrab,
          outputPath: r'C:\tmp\region.png',
        ),
        [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'gdigrab',
          '-offset_x',
          '100',
          '-offset_y',
          '50',
          '-video_size',
          '640x480',
          '-i',
          'desktop',
          '-frames:v',
          '1',
          '-y',
          r'C:\tmp\region.png',
        ],
      );
    });

    test('wfRecorder 分支抛错(遮罩仅 X11/Windows)', () {
      expect(
        () => buildSingleFrameCaptureArgs(
          physicalRect: rect,
          kind: RecordCommandKind.wfRecorder,
          outputPath: '/tmp/region.png',
        ),
        throwsArgumentError,
      );
    });
  });
}

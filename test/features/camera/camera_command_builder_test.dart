import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/camera/application/camera_command_builder.dart';

/// 相机采集命令装配快照(v4l2/dshow 精确数组断言)。
void main() {
  const builder = CameraCommandBuilder();
  const base = CaptureParams(); // fps 15, 30s, 无分辨率

  group('v4l2(Linux)', () {
    test('全参:mjpeg 恒定 + video_size + framerate + -t 前置限时', () {
      final params = base.copyWith(
        resolutionWidth: 1280,
        resolutionHeight: 720,
      );
      expect(
        builder.build(
          params: params,
          kind: CameraInputKind.v4l2,
          input: '/dev/video0',
          outputPath: '/tmp/capture.mp4',
        ),
        [
          '-f',
          'v4l2',
          '-input_format',
          'mjpeg',
          '-video_size',
          '1280x720',
          '-framerate',
          '15',
          '-t',
          '00:00:30.000',
          '-i',
          '/dev/video0',
          '-pix_fmt',
          'yuv420p',
          '-y',
          '/tmp/capture.mp4',
        ],
      );
    });

    test('缺分辨率:省略 -video_size(设备默认尺寸)', () {
      final args = builder.build(
        params: base,
        kind: CameraInputKind.v4l2,
        input: '/dev/video0',
        outputPath: '/tmp/capture.mp4',
      );
      expect(args, isNot(contains('-video_size')));
      expect(
        args,
        containsAllInOrder(['-f', 'v4l2', '-input_format', 'mjpeg']),
      );
    });

    test('单边分辨率:不注入 -video_size(双边齐全才注入)', () {
      final params = base.copyWith(resolutionWidth: 1280);
      final args = builder.build(
        params: params,
        kind: CameraInputKind.v4l2,
        input: '/dev/video0',
        outputPath: '/tmp/capture.mp4',
      );
      expect(args, isNot(contains('-video_size')));
    });

    test('时长上限 10s → -t 00:00:10.000;帧率 30', () {
      final params = base.copyWith(fps: 30, maxDurationMs: 10000);
      final args = builder.build(
        params: params,
        kind: CameraInputKind.v4l2,
        input: '/dev/video0',
        outputPath: '/tmp/capture.mp4',
      );
      expect(
        args,
        containsAllInOrder(['-framerate', '30', '-t', '00:00:10.000']),
      );
    });
  });

  group('dshow(Windows)', () {
    test('全参:video="名" 整串传入(设备名含空格)', () {
      final params = base.copyWith(
        resolutionWidth: 1280,
        resolutionHeight: 720,
      );
      expect(
        builder.build(
          params: params,
          kind: CameraInputKind.dshow,
          input: 'HD Pro Webcam C920',
          outputPath: r'C:\tmp\capture.mp4',
        ),
        [
          '-f',
          'dshow',
          '-framerate',
          '15',
          '-video_size',
          '1280x720',
          '-t',
          '00:00:30.000',
          '-i',
          'video="HD Pro Webcam C920"',
          '-pix_fmt',
          'yuv420p',
          '-y',
          r'C:\tmp\capture.mp4',
        ],
      );
    });

    test('缺分辨率:省略 -video_size', () {
      final args = builder.build(
        params: base,
        kind: CameraInputKind.dshow,
        input: 'Integrated Camera',
        outputPath: r'C:\tmp\capture.mp4',
      );
      expect(args, isNot(contains('-video_size')));
      expect(args[args.indexOf('-i') + 1], 'video="Integrated Camera"');
    });
  });

  group('通用契约', () {
    test('-t 恒在 -i 前(输入限时语义),-y 恒在输出前', () {
      for (final kind in CameraInputKind.values) {
        final args = builder.build(
          params: base,
          kind: kind,
          input: kind == CameraInputKind.v4l2 ? '/dev/video0' : 'Cam',
          outputPath: '/tmp/out.mp4',
        );
        final iIndex = args.indexOf('-i');
        final tIndex = args.indexOf('-t');
        final yIndex = args.indexOf('-y');
        expect(tIndex, lessThan(iIndex), reason: '$kind -t 前置限时');
        expect(yIndex, greaterThan(iIndex), reason: '$kind -y 在输入后');
        expect(args.last, '/tmp/out.mp4');
      }
    });
  });
}

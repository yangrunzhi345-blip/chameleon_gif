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

  group('buildPreview(截帧预览)', () {
    test('v4l2:采集 → fps=15 + scale=960 + q:v 3 → image2pipe/mjpeg 管道', () {
      expect(
        builder.buildPreview(
          params: base,
          kind: CameraInputKind.v4l2,
          input: '/dev/video0',
        ),
        [
          '-f',
          'v4l2',
          '-input_format',
          'mjpeg',
          '-framerate',
          '15',
          '-i',
          '/dev/video0',
          '-an',
          '-vf',
          'fps=15,scale=960:-2',
          '-f',
          'image2pipe',
          '-vcodec',
          'mjpeg',
          '-q:v',
          '3',
          'pipe:1',
        ],
      );
    });

    test('无 -t(恒运行,生命周期由端口层控制);pipe:1 结尾', () {
      final args = builder.buildPreview(
        params: base,
        kind: CameraInputKind.v4l2,
        input: '/dev/video0',
      );
      expect(args, isNot(contains('-t')));
      expect(args.last, 'pipe:1');
    });

    test('dshow:设备名整串 + 同尾链', () {
      final args = builder.buildPreview(
        params: base,
        kind: CameraInputKind.dshow,
        input: 'HD Pro Webcam C920',
      );
      expect(args, containsAllInOrder(['-i', 'video="HD Pro Webcam C920"']));
      expect(args, containsAllInOrder(['-vf', 'fps=15,scale=960:-2']));
      expect(args, containsAllInOrder(['-q:v', '3']));
      expect(args.last, 'pipe:1');
    });
  });

  group('buildWithPreview(录制 + 预览帧管道)', () {
    test('v4l2:单采集双编码器(mp4 文件 + image2pipe 预览帧)', () {
      final args = builder.buildWithPreview(
        params: base,
        kind: CameraInputKind.v4l2,
        input: '/dev/video0',
        outputPath: '/tmp/out.mp4',
      );
      // 输入限时 + 双 -map 0:v
      expect(args, containsAllInOrder(['-t', '00:00:30.000']));
      final mapCount = args.where((a) => a == '-map').length;
      expect(mapCount, 2, reason: '双输出各 -map 0:v');
      // 文件输出:libx264 → mp4
      expect(
        args,
        containsAllInOrder([
          '-c:v',
          'libx264',
          '-f',
          'mp4',
          '-y',
          '/tmp/out.mp4',
        ]),
      );
      // 预览输出:mjpeg 帧管道(与 buildPreview 同构)
      expect(args, containsAllInOrder(['-vf', 'fps=15,scale=960:-2']));
      expect(args, containsAllInOrder(['-c:v', 'mjpeg', '-q:v', '3']));
      expect(args, containsAllInOrder(['-f', 'image2pipe', 'pipe:1']));
    });

    test('dshow:设备名整串 + 双输出', () {
      final args = builder.buildWithPreview(
        params: base.copyWith(resolutionWidth: 1280, resolutionHeight: 720),
        kind: CameraInputKind.dshow,
        input: 'Integrated Camera',
        outputPath: r'C:\tmp\out.mp4',
      );
      expect(args, containsAllInOrder(['-video_size', '1280x720']));
      expect(args, containsAllInOrder(['-f', 'mp4', '-y', r'C:\tmp\out.mp4']));
      expect(args, containsAllInOrder(['-f', 'image2pipe', 'pipe:1']));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/features/screen_record/application/record_command_builder.dart';

/// 录屏命令装配快照(x11grab/pipewire/gdigrab 三分支精确数组断言;
/// pipewire 分支无真机环境,本测试是其唯一契约锁定点)。
void main() {
  const builder = RecordCommandBuilder();
  const defaultParams = RecordParams(); // fps 15, 60s, 全屏, 带光标

  group('x11grab(Linux X11)', () {
    test('全屏:省略 -video_size(屏幕原生),带光标', () {
      expect(
        builder.build(
          params: defaultParams,
          kind: RecordCommandKind.x11grab,
          display: ':1',
          outputPath: '/tmp/out.mp4',
        ),
        [
          '-f',
          'x11grab',
          '-framerate',
          '15',
          '-draw_mouse',
          '1',
          '-t',
          '00:01:00.000',
          '-i',
          ':1',
          '-an',
          '-pix_fmt',
          'yuv420p',
          '-y',
          '/tmp/out.mp4',
        ],
      );
    });

    test('自定义区域:video_size + DISPLAY+x+y 偏移', () {
      final params = defaultParams.copyWith(
        regionMode: RecordRegion.custom,
        regionX: 100,
        regionY: 50,
        regionWidth: 640,
        regionHeight: 480,
      );
      expect(
        builder.build(
          params: params,
          kind: RecordCommandKind.x11grab,
          display: ':1',
          outputPath: '/tmp/out.mp4',
        ),
        [
          '-f',
          'x11grab',
          '-framerate',
          '15',
          '-video_size',
          '640x480',
          '-draw_mouse',
          '1',
          '-t',
          '00:01:00.000',
          '-i',
          ':1+100+50',
          '-an',
          '-pix_fmt',
          'yuv420p',
          '-y',
          '/tmp/out.mp4',
        ],
      );
    });

    test('光标关闭:-draw_mouse 0', () {
      final params = defaultParams.copyWith(drawCursor: false);
      final args = builder.build(
        params: params,
        kind: RecordCommandKind.x11grab,
        display: ':0',
        outputPath: '/tmp/out.mp4',
      );
      expect(args, containsAllInOrder(['-draw_mouse', '0']));
    });

    test('自定义区域缺宽高 → 回退全屏', () {
      final params = defaultParams.copyWith(
        regionMode: RecordRegion.custom,
        regionX: 10,
        regionY: 20,
      );
      final args = builder.build(
        params: params,
        kind: RecordCommandKind.x11grab,
        display: ':1',
        outputPath: '/tmp/out.mp4',
      );
      expect(args, isNot(contains('-video_size')));
      expect(args[args.indexOf('-i') + 1], ':1');
    });
  });

  group('pipewire(Linux Wayland)', () {
    test('仅全屏:忽略区域/光标参数', () {
      final params = defaultParams.copyWith(
        regionMode: RecordRegion.custom,
        regionX: 10,
        regionY: 20,
        regionWidth: 320,
        regionHeight: 240,
        drawCursor: false,
      );
      expect(
        builder.build(
          params: params,
          kind: RecordCommandKind.pipewire,
          outputPath: '/tmp/out.mp4',
        ),
        [
          '-f',
          'pipewire',
          '-i',
          'auto',
          '-t',
          '00:01:00.000',
          '-an',
          '-pix_fmt',
          'yuv420p',
          '-y',
          '/tmp/out.mp4',
        ],
      );
    });
  });

  group('gdigrab(Windows)', () {
    test('全屏:desktop 输入', () {
      expect(
        builder.build(
          params: defaultParams,
          kind: RecordCommandKind.gdigrab,
          outputPath: r'C:\tmp\out.mp4',
        ),
        [
          '-f',
          'gdigrab',
          '-framerate',
          '15',
          '-t',
          '00:01:00.000',
          '-i',
          'desktop',
          '-an',
          '-pix_fmt',
          'yuv420p',
          '-y',
          r'C:\tmp\out.mp4',
        ],
      );
    });

    test('自定义区域:offset_x/offset_y/video_size', () {
      final params = defaultParams.copyWith(
        regionMode: RecordRegion.custom,
        regionX: 100,
        regionY: 50,
        regionWidth: 640,
        regionHeight: 480,
      );
      final args = builder.build(
        params: params,
        kind: RecordCommandKind.gdigrab,
        outputPath: r'C:\tmp\out.mp4',
      );
      expect(
        args,
        containsAllInOrder([
          '-offset_x',
          '100',
          '-offset_y',
          '50',
          '-video_size',
          '640x480',
          '-i',
          'desktop',
        ]),
      );
    });

    test('窗口模式:title= 输入(窗口标题含空格原样传入)', () {
      final params = defaultParams.copyWith(
        regionMode: RecordRegion.window,
        windowTitle: 'Chameleon Gif - 未命名文档',
      );
      final args = builder.build(
        params: params,
        kind: RecordCommandKind.gdigrab,
        outputPath: r'C:\tmp\out.mp4',
      );
      expect(args[args.indexOf('-i') + 1], 'title=Chameleon Gif - 未命名文档');
    });
  });

  group('通用契约', () {
    test('时长上限 30s → -t 00:00:30.000;帧率小数保留', () {
      final params = defaultParams.copyWith(fps: 15.5, maxDurationMs: 30000);
      final args = builder.build(
        params: params,
        kind: RecordCommandKind.gdigrab,
        outputPath: '/tmp/out.mp4',
      );
      expect(
        args,
        containsAllInOrder(['-framerate', '15.5', '-t', '00:00:30.000']),
      );
    });

    test('尾链恒定:-an -pix_fmt yuv420p -y', () {
      for (final kind in RecordCommandKind.values) {
        final args = builder.build(
          params: defaultParams,
          kind: kind,
          display: kind == RecordCommandKind.x11grab ? ':1' : null,
          outputPath: '/tmp/out.mp4',
        );
        expect(args.sublist(args.length - 5), [
          '-an',
          '-pix_fmt',
          'yuv420p',
          '-y',
          '/tmp/out.mp4',
        ], reason: '$kind 尾链锁定');
      }
    });
  });
}

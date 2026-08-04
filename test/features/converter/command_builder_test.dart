import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/utils/duration_format.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/features/converter/application/command_builder.dart';
import 'package:gif_forge/features/converter/application/gif_command.dart';

/// [GifCommandBuilder] 快照测试(docs/14-测试计划.md §14.2,命令契约锁定)。
void main() {
  const builder = GifCommandBuilder();
  const video = VideoInfo(
    path: '/tmp/videos/demo.mp4',
    formatName: 'mov,mp4',
    duration: Duration(seconds: 30),
    width: 1280,
    height: 720,
    fps: 30,
    codec: 'h264',
  );

  group('标准单遍(usePalette=false)', () {
    test('默认参数命令快照逐项相等', () {
      const setting = GifSetting();
      final commands = builder.build(
        setting: setting,
        video: video,
        inputPath: video.path,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
        usePalette: false,
      );

      expect(commands, hasLength(1));
      final cmd = commands.single;
      expect(cmd.label, GifCommand.encodeLabel);
      expect(cmd.args, [
        '-ss',
        '00:00:00.000',
        '-to',
        '00:00:30.000',
        '-i',
        '/tmp/videos/demo.mp4',
        '-vf',
        'fps=15,scale=480:-1:flags=lanczos',
        '-progress',
        'pipe:1',
        '-y',
        '-loop',
        '0',
        '/tmp/work/out.gif',
      ]);
    });

    test('width=0 省略 scale 滤镜项', () {
      const setting = GifSetting(width: 0);
      final cmd = builder
          .build(
            setting: setting,
            video: video,
            inputPath: video.path,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(cmd.args, contains('-vf'));
      final vf = cmd.args[cmd.args.indexOf('-vf') + 1];
      expect(vf, 'fps=15', reason: 'width=0 时滤镜链只有 fps');
    });

    test('非整数 fps 原样透传', () {
      const setting = GifSetting(fps: 29.97);
      final cmd = builder
          .build(
            setting: setting,
            video: video,
            inputPath: video.path,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      final vf = cmd.args[cmd.args.indexOf('-vf') + 1];
      expect(vf, 'fps=29.97,scale=480:-1:flags=lanczos');
    });

    test('loop 映射为 -loop <n>', () {
      const setting = GifSetting(loop: 2);
      final cmd = builder
          .build(
            setting: setting,
            video: video,
            inputPath: video.path,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      final loopIdx = cmd.args.indexOf('-loop');
      expect(loopIdx, greaterThanOrEqualTo(0));
      expect(cmd.args[loopIdx + 1], '2');
    });

    test('start/end 裁剪映射到 -ss/-to(前置在 -i 前)', () {
      const setting = GifSetting(
        start: Duration(minutes: 1, seconds: 30, milliseconds: 500),
        end: Duration(minutes: 2),
      );
      final cmd = builder
          .build(
            setting: setting,
            video: video,
            inputPath: video.path,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(cmd.args.take(6), [
        '-ss',
        '00:01:30.500',
        '-to',
        '00:02:00.000',
        '-i',
        video.path,
      ]);
    });

    test('end=null 时取 video.duration', () {
      const setting = GifSetting();
      final cmd = builder
          .build(
            setting: setting,
            video: video,
            inputPath: video.path,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(cmd.args.take(5), [
        '-ss',
        '00:00:00.000',
        '-to',
        '00:00:30.000',
        '-i',
      ]);
    });
  });

  group('调色板两遍(默认)', () {
    test('第一遍 palettegen 无 -progress,第二遍 paletteuse 带 -progress', () {
      const setting = GifSetting();
      final commands = builder.build(
        setting: setting,
        video: video,
        inputPath: video.path,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );

      expect(commands, hasLength(2));
      expect(commands[0].label, GifCommand.paletteLabel);
      expect(commands[1].label, GifCommand.encodeLabel);

      // 第一遍:生成调色板到 workDir
      final first = commands[0].args;
      expect(first, isNot(contains('-progress')));
      expect(first, isNot(contains('pipe:1')));
      final vf1 = first[first.indexOf('-vf') + 1];
      expect(
        vf1,
        'fps=15,scale=480:-1:flags=lanczos,palettegen=max_colors=256',
      );
      expect(first.last, '/tmp/work/palette.png');

      // 第二遍:应用调色板输出 GIF(第二个 -i 为调色板输入)
      final second = commands[1].args;
      expect(second, contains('-i'));
      expect(second[second.lastIndexOf('-i') + 1], '/tmp/work/palette.png');
      final lavfi = second[second.indexOf('-lavfi') + 1];
      expect(
        lavfi,
        'fps=15,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5',
      );
      expect(second, containsAll(['-progress', 'pipe:1']));
      expect(second.last, '/tmp/work/out.gif');
    });

    test('两遍均携带裁剪参数且顺序一致', () {
      const setting = GifSetting(start: Duration(seconds: 5));
      final commands = builder.build(
        setting: setting,
        video: video,
        inputPath: video.path,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );
      for (final cmd in commands) {
        expect(cmd.args.take(5), [
          '-ss',
          '00:00:05.000',
          '-to',
          '00:00:30.000',
          '-i',
        ]);
      }
    });
  });

  group('进度分母 progressDenominator', () {
    test('end 缺省时 = video.duration - start', () {
      const setting = GifSetting(start: Duration(seconds: 10));
      expect(
        builder.progressDenominator(setting, video),
        const Duration(seconds: 20),
      );
    });

    test('end 指定时 = end - start', () {
      const setting = GifSetting(
        start: Duration(seconds: 10),
        end: Duration(seconds: 25),
      );
      expect(
        builder.progressDenominator(setting, video),
        const Duration(seconds: 15),
      );
    });

    test('start >= end 时钳制为 0(除零防护)', () {
      const setting = GifSetting(
        start: Duration(seconds: 20),
        end: Duration(seconds: 10),
      );
      expect(builder.progressDenominator(setting, video), Duration.zero);
    });
  });

  group('formatFfmpegTime', () {
    test('毫秒精度 HH:MM:SS.mmm', () {
      expect(formatFfmpegTime(Duration.zero), '00:00:00.000');
      expect(
        formatFfmpegTime(
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 456),
        ),
        '01:02:03.456',
      );
      expect(formatFfmpegTime(const Duration(milliseconds: 5)), '00:00:00.005');
      expect(formatFfmpegTime(const Duration(hours: 25)), '25:00:00.000');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/converter/application/command_builder.dart';
import 'package:chameleon_gif/features/converter/application/gif_command.dart';

/// [GifCommandBuilder.buildFromImages] 快照测试(图片模式命令契约锁定,
/// 模板与 command_builder_test.dart 一致)。
void main() {
  const builder = GifCommandBuilder();
  const source = ImageGifSource(
    paths: ['/img/1.png', '/img/2.png', '/img/3.png'],
    width: 640,
    height: 480,
  );

  /// 取 filter_complex 的值(-filter_complex 的后一个参数)
  String filterOf(List<String> args) {
    return args[args.indexOf('-filter_complex') + 1];
  }

  group('默认两遍调色板法', () {
    test('默认参数命令快照逐项相等', () {
      const setting = GifSetting(frameDurationMs: 1000);
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );

      expect(commands, hasLength(2));

      // 第一遍:palette 无 -progress,输出 palette.png
      final palette = commands[0];
      expect(palette.label, GifCommand.kPaletteLabel);
      expect(palette.args, [
        // 每图输入:-loop 1 -t 1s -framerate 15
        '-loop',
        '1',
        '-t',
        '00:00:01.000',
        '-framerate',
        '15',
        '-i',
        '/img/1.png',
        '-loop',
        '1',
        '-t',
        '00:00:01.000',
        '-framerate',
        '15',
        '-i',
        '/img/2.png',
        '-loop',
        '1',
        '-t',
        '00:00:01.000',
        '-framerate',
        '15',
        '-i',
        '/img/3.png',
        '-filter_complex',
        '[0:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s0];'
            '[1:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s1];'
            '[2:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s2];'
            '[s0][s1][s2]concat=n=3:v=1:a=0[vout];'
            '[vout]palettegen=max_colors=256[pal]',
        '-map', '[pal]',
        '-y',
        '/tmp/work/palette.png',
      ]);

      // 第二遍:encode 带 -progress,palette 为第 N(=3)个输入,显式 -map
      final encode = commands[1];
      expect(encode.label, GifCommand.kEncodeLabel);
      // 输入序列(3 图 × 8 项)与 palette 遍逐项一致
      expect(
        encode.args.sublist(0, 24),
        palette.args.sublist(0, 24),
        reason: 'encode 遍输入序列与 palette 遍一致',
      );
      // 第 N 个输入是 palette.png(0-based N = 图片数)
      final encodeArgs = encode.args;
      final inputPositions = <int>[];
      for (var i = 0; i < encodeArgs.length; i++) {
        if (encodeArgs[i] == '-i') inputPositions.add(i);
      }
      expect(inputPositions, hasLength(4));
      expect(encodeArgs[inputPositions.last + 1], '/tmp/work/palette.png');
      expect(
        filterOf(encodeArgs),
        '[0:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s0];'
        '[1:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s1];'
        '[2:v]fps=15,scale=640:480:flags=lanczos,setsar=1[s2];'
        '[s0][s1][s2]concat=n=3:v=1:a=0[vout];'
        '[vout][3:v]paletteuse=dither=bayer:bayer_scale=5[gif]',
      );
      expect(
        encodeArgs,
        containsAllInOrder([
          '-map',
          '[gif]',
          '-progress',
          'pipe:1',
          '-y',
          '-loop',
          '0',
          '/tmp/work/out.gif',
        ]),
      );
    });

    test('palette 遍无 -progress,encode 遍有', () {
      const setting = GifSetting();
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );
      expect(commands[0].args, isNot(contains('-progress')));
      expect(commands[1].args, containsAllInOrder(['-progress', 'pipe:1']));
    });
  });

  group('scale 三语义', () {
    test('未指定宽高 → 统一到首图尺寸(concat 分辨率一致性)', () {
      const setting = GifSetting();
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=640:480:flags=lanczos'));
    });

    test('指定宽高 → 按指定尺寸', () {
      const setting = GifSetting(width: 480, height: 270);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=480:270:flags=lanczos'));
    });

    test('首图尺寸未知且未指定 → 无 scale(仅 fps)', () {
      const setting = GifSetting();
      const unknown = ImageGifSource(paths: ['/img/1.png', '/img/2.png']);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: unknown,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('fps=15,setsar=1'));
      expect(filterOf(cmd.args), isNot(contains('scale=')));
    });
  });

  group('单遍(usePalette=false)', () {
    test('仅一条 encode 命令,带 -progress 与 -loop', () {
      const setting = GifSetting(loop: 2);
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
        usePalette: false,
      );
      expect(commands, hasLength(1));
      final cmd = commands.single;
      expect(cmd.label, GifCommand.kEncodeLabel);
      expect(cmd.args.sublist(cmd.args.length - 6), [
        '-progress',
        'pipe:1',
        '-y',
        '-loop',
        '2',
        '/tmp/work/out.gif',
      ]);
    });
  });

  group('时长与帧率', () {
    test('frameDurationMs 显式 → -t 用显式值', () {
      const setting = GifSetting(frameDurationMs: 500);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(cmd.args, containsAllInOrder(['-t', '00:00:00.500']));
    });

    test('frameDurationMs 为 null → 由 fps 推导(每图一帧)', () {
      const setting = GifSetting(fps: 10);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      // 1e6/10 = 100000 µs = 100 ms
      expect(cmd.args, containsAllInOrder(['-t', '00:00:00.100']));
    });

    test('非整数 fps 原样透传 -framerate 与滤镜', () {
      const setting = GifSetting(fps: 29.97);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(cmd.args, containsAllInOrder(['-framerate', '29.97']));
      expect(filterOf(cmd.args), contains('fps=29.97'));
    });

    test('单图(N=1)concat=n=1 合法', () {
      const setting = GifSetting(frameDurationMs: 1000);
      const single = ImageGifSource(paths: ['/img/only.png']);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: single,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('concat=n=1:v=1:a=0[vout]'));
    });
  });

  group('progressDenominatorImages', () {
    test('= N × 每图时长', () {
      const setting = GifSetting(frameDurationMs: 1000);
      expect(
        builder.progressDenominatorImages(setting, source),
        const Duration(seconds: 3),
      );
    });

    test('frameDurationMs 为 null 时由 fps 推导', () {
      const setting = GifSetting(fps: 10);
      // 3 图 × 100ms
      expect(
        builder.progressDenominatorImages(setting, source),
        const Duration(milliseconds: 300),
      );
    });
  });
}

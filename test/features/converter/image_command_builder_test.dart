import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/per_image_control.dart';
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

  /// 画布 640×480 的单图默认链(未精细控制:contain 填满画布 + 透明 pad)。
  const defaultChain =
      'fps=15,scale=640:480:flags=lanczos:'
      'force_original_aspect_ratio=decrease,format=rgba,'
      'pad=640:480:(ow-iw)/2:(oh-ih)/2:color=0x00000000,setsar=1';

  /// 三图 stages + concat(不含 palettegen/paletteuse 尾段)。
  String stages3(String chain) =>
      '[0:v]$chain[s0];[1:v]$chain[s1];[2:v]$chain[s2];'
      '[s0][s1][s2]concat=n=3:v=1:a=0[vout]';

  /// 同 [stages3] 但 concat **无输出标签**(播放速度分支专用:concat 带
  /// 标签后链内隐式连接失效会致 setpts 输入悬空,链尾由 setpts 统一加
  /// [vout],见 command_builder 注释与 tool/convert_check_images.dart)。
  String stages3NoLabel(String chain) =>
      '[0:v]$chain[s0];[1:v]$chain[s1];[2:v]$chain[s2];'
      '[s0][s1][s2]concat=n=3:v=1:a=0';

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
        '${stages3(defaultChain)};'
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
        '${stages3(defaultChain)};'
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

  group('画布与不扭曲语义', () {
    test('未指定宽高 → 画布 = 首图尺寸,每图 contain 填满 + 透明 pad', () {
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
      expect(filterOf(cmd.args), stages3(defaultChain));
    });

    test('指定宽高 → 画布 = 指定尺寸(所有图 contain 该画布)', () {
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
      expect(filterOf(cmd.args), contains('scale=480:270:flags=lanczos:'));
      expect(filterOf(cmd.args), contains('pad=480:270:'));
    });

    test('首图尺寸未知且未指定 → 无 scale(仅 fps,退化兜底)', () {
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

    test('仅指定宽度 → 画布另一侧按首图宽高比推算', () {
      // 源 640×480(4:3),宽 320 → 画布 320×240
      const setting = GifSetting(width: 320);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=320:240:flags=lanczos:'));
      expect(filterOf(cmd.args), contains('pad=320:240:'));
    });

    test('仅指定高度 → 画布另一侧按首图宽高比推算', () {
      // 源 640×480(4:3),高 360 → 画布 480×360
      const setting = GifSetting(height: 360);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=480:360:flags=lanczos:'));
      expect(filterOf(cmd.args), contains('pad=480:360:'));
    });

    test('单边指定 + 首图尺寸未知 → 退化无画布,无控制时不缩放', () {
      const setting = GifSetting(width: 320);
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

  group('每图精细化控制', () {
    test('双边指定 → 精确尺寸允许变形 + min 钳制 + 透明 pad', () {
      const setting = GifSetting();
      const controlled = ImageGifSource(
        paths: ['/img/1.png', '/img/2.png', '/img/3.png'],
        width: 640,
        height: 480,
        perImageControls: [
          PerImageControl(width: 480, height: 480),
          PerImageControl(),
          PerImageControl(),
        ],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(
        filterOf(cmd.args),
        '[0:v]fps=15,scale=480:480:flags=lanczos,'
        'scale=min(iw\\,640):min(ih\\,480):flags=lanczos:'
        'force_original_aspect_ratio=decrease,format=rgba,'
        'pad=640:480:(ow-iw)/2:(oh-ih)/2:color=0x00000000,setsar=1[s0];'
        '[1:v]$defaultChain[s1];[2:v]$defaultChain[s2];'
        '[s0][s1][s2]concat=n=3:v=1:a=0[vout]',
      );
    });

    test('仅指定宽度 → 等比 + 钳制', () {
      const setting = GifSetting();
      const controlled = ImageGifSource(
        paths: ['/img/1.png'],
        width: 640,
        height: 480,
        perImageControls: [PerImageControl(width: 320)],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(
        filterOf(cmd.args),
        '[0:v]fps=15,scale=320:-1:flags=lanczos,'
        'scale=min(iw\\,640):min(ih\\,480):flags=lanczos:'
        'force_original_aspect_ratio=decrease,format=rgba,'
        'pad=640:480:(ow-iw)/2:(oh-ih)/2:color=0x00000000,setsar=1[s0];'
        '[s0]concat=n=1:v=1:a=0[vout]',
      );
    });

    test('仅指定高度 → 等比 + 钳制', () {
      const setting = GifSetting();
      const controlled = ImageGifSource(
        paths: ['/img/1.png'],
        width: 640,
        height: 480,
        perImageControls: [PerImageControl(height: 270)],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=-1:270:flags=lanczos,'));
      expect(filterOf(cmd.args), contains('pad=640:480:'));
    });

    test('仅倍数 → iw/ih 表达式等比(整数倍率无小数点)', () {
      const setting = GifSetting();
      const controlled = ImageGifSource(
        paths: ['/img/1.png'],
        width: 640,
        height: 480,
        perImageControls: [PerImageControl(scaleMultiplier: 2)],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), contains('scale=iw*2:ih*2:flags=lanczos,'));
    });

    test('非整数倍率原样透传', () {
      const setting = GifSetting();
      const controlled = ImageGifSource(
        paths: ['/img/1.png'],
        width: 640,
        height: 480,
        perImageControls: [PerImageControl(scaleMultiplier: 1.5)],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(
        filterOf(cmd.args),
        contains('scale=iw*1.5:ih*1.5:flags=lanczos,'),
      );
    });

    test('全默认控制列表 ≡ 无控制(不改变命令)', () {
      const setting = GifSetting();
      const plainSource = ImageGifSource(
        paths: ['/img/1.png', '/img/2.png'],
        width: 640,
        height: 480,
      );
      const controlled = ImageGifSource(
        paths: ['/img/1.png', '/img/2.png'],
        width: 640,
        height: 480,
        perImageControls: [
          PerImageControl(),
          PerImageControl(scaleMultiplier: 1.0, width: 0, height: 0),
        ],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: controlled,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      final plain = builder
          .buildFromImages(
            setting: setting,
            source: plainSource,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(filterOf(cmd.args), filterOf(plain.args));
    });

    test('退化链(画布未知)+ 控制 → 仅控制 scale,无 pad', () {
      const setting = GifSetting();
      const unknown = ImageGifSource(
        paths: ['/img/1.png'],
        perImageControls: [PerImageControl(width: 320)],
      );
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: unknown,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(
        filterOf(cmd.args),
        '[0:v]fps=15,scale=320:-1:flags=lanczos,setsar=1[s0];'
        '[s0]concat=n=1:v=1:a=0[vout]',
      );
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

  group('播放速度(慢放/加速)', () {
    test('speed=2 → concat 后整体 setpts,输出标签沿用 [vout]', () {
      const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 2);
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );
      // palette 遍:concat 不加标签(带标签会致 setpts 输入悬空,已实证
      // exit 234),链尾 ',setpts=PTS/2[vout]' 统一加标签再 palettegen
      expect(
        filterOf(commands[0].args),
        '${stages3NoLabel(defaultChain)},setpts=PTS/2[vout];'
        '[vout]palettegen=max_colors=256[pal]',
      );
      // encode 遍:setpts 后 [vout][3:v]paletteuse
      expect(
        filterOf(commands[1].args),
        '${stages3NoLabel(defaultChain)},setpts=PTS/2[vout];'
        '[vout][3:v]paletteuse=dither=bayer:bayer_scale=5[gif]',
      );
      // 逐图输入 -t 不变(每图 1s,不因加速改输入)
      expect(commands[0].args, containsAllInOrder(['-t', '00:00:01.000']));
    });

    test('speed=2 单遍:concat 无标签、setpts 链尾统一加 [vout](无双标签)', () {
      const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 2);
      final cmd = builder
          .buildFromImages(
            setting: setting,
            source: source,
            workDir: '/tmp/work',
            outputPath: '/tmp/work/out.gif',
            usePalette: false,
          )
          .single;
      expect(
        filterOf(cmd.args),
        '${stages3NoLabel(defaultChain)},setpts=PTS/2[vout]',
      );
      expect(
        filterOf(cmd.args),
        isNot(contains('[vout],setpts')),
        reason: 'concat 不得带输出标签(speed≠1 时)',
      );
    });

    test('慢放 0.25 → setpts=PTS/0.25', () {
      const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 0.25);
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );
      expect(filterOf(commands[0].args), contains(',setpts=PTS/0.25[vout]'));
    });

    test('speed=1(默认)→ 不注入 setpts(默认快照测试已锁定)', () {
      const setting = GifSetting(frameDurationMs: 1000);
      final commands = builder.buildFromImages(
        setting: setting,
        source: source,
        workDir: '/tmp/work',
        outputPath: '/tmp/work/out.gif',
      );
      expect(filterOf(commands[0].args), contains('[vout]'));
      expect(filterOf(commands[0].args), isNot(contains('setpts')));
    });

    test('进度分母 = N × 每图时长 ÷ speed', () {
      const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 2);
      // 3 图 × 1s ÷ 2 = 1.5s
      expect(
        builder.progressDenominatorImages(setting, source),
        const Duration(milliseconds: 1500),
      );
    });

    test('慢放 0.25 → 进度分母 ×4', () {
      const setting = GifSetting(frameDurationMs: 1000, playbackSpeed: 0.25);
      // 3 图 × 1s ÷ 0.25 = 12s
      expect(
        builder.progressDenominatorImages(setting, source),
        const Duration(seconds: 12),
      );
    });
  });
}

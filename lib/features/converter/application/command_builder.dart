import 'dart:math' as math;

import '../../../core/utils/duration_format.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import 'gif_command.dart';

/// FFmpeg 命令构造器(纯函数,可独立单测,docs/08-FFmpeg设计.md §8.3.2)。
///
/// 输入 [GifSetting] + [VideoInfo] → 输出命令列表:
/// - 标准单遍(usePalette=false):1 条 encode 命令;
/// - 高质调色板两遍(默认):palette → encode。
///
/// 契约(快照单测锁定,禁止随意改动参数语义):
/// - `-ss`/`-to` 前置在 `-i` 前(快速定位,提高裁剪精度);
/// - `end == Duration.zero`(时长未知的恢复兜底哨兵)省略 `-to`,输出全片
///   (ffmpeg 8 对 `-to 0` 报 "-to value smaller than -ss" abort,见 P7 修复);
/// - `width=0` 省略 scale 滤镜项(原图等比);
/// - `end == null` 时取 `video.duration`(导入时未裁剪);
/// - `loop` 映射为 `-loop <n>`(0 = 无限循环),两个模式均生效;
/// - 进度只在 encode 遍携带 `-progress pipe:1`(palette 遍无输出进度)。
class GifCommandBuilder {
  const GifCommandBuilder();

  /// 构造命令列表(第一遍 palette 在前,依赖序)。
  List<GifCommand> build({
    required GifSetting setting,
    required VideoInfo video,
    required String inputPath,
    required String workDir,
    required String outputPath,
    bool usePalette = true,
  }) {
    final end = setting.end ?? video.duration;
    final filter = _filterChain(setting);
    if (!usePalette) {
      return [
        GifCommand(
          args: [
            ..._trimArgs(setting, end, inputPath),
            '-vf',
            filter,
            '-progress',
            'pipe:1',
            '-y',
            '-loop',
            '${setting.loop}',
            outputPath,
          ],
          label: GifCommand.kEncodeLabel,
        ),
      ];
    }
    final palettePath = '$workDir/palette.png';
    return [
      // 第一遍:全局调色板(无 -progress,UI 显示阶段文案兜底)
      GifCommand(
        args: [
          ..._trimArgs(setting, end, inputPath),
          '-vf',
          '$filter,palettegen=max_colors=256',
          '-y',
          palettePath,
        ],
        label: GifCommand.kPaletteLabel,
      ),
      // 第二遍:应用调色板输出 GIF
      GifCommand(
        args: [
          ..._trimArgs(setting, end, inputPath),
          '-i',
          palettePath,
          '-lavfi',
          '$filter[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5',
          '-progress',
          'pipe:1',
          '-y',
          '-loop',
          '${setting.loop}',
          outputPath,
        ],
        label: GifCommand.kEncodeLabel,
      ),
    ];
  }

  /// 进度百分比分母 = 裁剪时长 `(end ?? video.duration) - start`,
  /// 供 [ProgressParser] 计算百分比(§8.3.3);负值钳制为 0。
  Duration progressDenominator(GifSetting setting, VideoInfo video) {
    final d = (setting.end ?? video.duration) - setting.start;
    return d.isNegative ? Duration.zero : d;
  }

  /// 构造多图片合成 GIF 的命令列表(图片模式,docs/08-FFmpeg设计.md 图片节)。
  ///
  /// 命令形态(与 [build] 的视频路径互不影响):
  /// - 每张图片一个输入 `-loop 1 -t <D> -framerate <F> -i img`:
  ///   `-loop 1` 无限循环该帧,输入 `-t` 只作用于该输入,产出 D 秒帧段;
  ///   未来若需逐图独立时长,把统一 D 换成逐输入的 `-t D_i` 即可,结构不变。
  /// - filter_complex:每输入 `[i:v]fps=F,scale=...[s_i]`(scale 语义与
  ///   视频一致,未指定宽高时统一到首图尺寸 —— concat 要求各输入分辨率一致),
  ///   再 `[s0]...[sN-1]concat=n=N:v=1:a=0[vout]`。
  /// - 两遍调色板法:palette 遍 `[vout]palettegen=...[pal] -map "[pal]"`(无
  ///   -progress);encode 遍 `[vout][N:v]paletteuse=...[gif] -map "[gif]"`
  ///   携带 `-progress pipe:1` 与输出 `-loop <n>`。显式 `-map` 保证三平台确定。
  List<GifCommand> buildFromImages({
    required GifSetting setting,
    required ImageGifSource source,
    required String workDir,
    required String outputPath,
    bool usePalette = true,
  }) {
    final n = source.paths.length;
    final inputs = _imageInputArgs(setting, source);
    final perInput = _perInputChain(setting, source);
    final stages = [
      for (var i = 0; i < n; i++) '[$i:v]$perInput[s$i]',
    ].join(';');
    final labels = [for (var i = 0; i < n; i++) '[s$i]'].join();
    final concatChain = '$stages;${labels}concat=n=$n:v=1:a=0[vout]';
    final tail = ['-y', '-loop', '${setting.loop}', outputPath];

    if (!usePalette) {
      return [
        GifCommand(
          args: [
            ...inputs,
            '-filter_complex',
            concatChain,
            '-map',
            '[vout]',
            '-progress',
            'pipe:1',
            ...tail,
          ],
          label: GifCommand.kEncodeLabel,
        ),
      ];
    }
    final palettePath = '$workDir/palette.png';
    return [
      // 第一遍:全局调色板(无 -progress,UI 显示阶段文案兜底)
      GifCommand(
        args: [
          ...inputs,
          '-filter_complex',
          '$concatChain;[vout]palettegen=max_colors=256[pal]',
          '-map',
          '[pal]',
          '-y',
          palettePath,
        ],
        label: GifCommand.kPaletteLabel,
      ),
      // 第二遍:应用调色板输出 GIF(palette 为第 N 个输入)
      GifCommand(
        args: [
          ...inputs,
          '-i',
          palettePath,
          '-filter_complex',
          '$concatChain;[vout][$n:v]paletteuse=dither=bayer:bayer_scale=5[gif]',
          '-map',
          '[gif]',
          '-progress',
          'pipe:1',
          ...tail,
        ],
        label: GifCommand.kEncodeLabel,
      ),
    ];
  }

  /// 图片模式进度百分比分母 = 总输出时长 `N × 每图时长`
  /// (encode 遍 out_time_us 沿 concat 时间轴 0 → ΣD)。
  Duration progressDenominatorImages(
    GifSetting setting,
    ImageGifSource source,
  ) {
    return source.totalDuration(setting);
  }

  /// 图片输入参数序列(每图 `-loop 1 -t D -framerate F -i path`)。
  List<String> _imageInputArgs(GifSetting setting, ImageGifSource source) {
    final d = formatFfmpegTime(setting.effectiveFrameDuration);
    final f = _formatFps(setting.fps);
    return [
      for (final path in source.paths) ...[
        '-loop',
        '1',
        '-t',
        d,
        '-framerate',
        f,
        '-i',
        path,
      ],
    ];
  }

  /// 图片模式单输入滤镜链:`fps=F` 恒在,scale 按宽高组合追加,`setsar=1` 兜底。
  ///
  /// 与 [_filterChain] 语义一致,差异:
  /// - 未指定宽高(全 0)时统一到首图尺寸;单边指定时另一边按首图宽高比
  ///   推算成定值 —— concat 要求各输入分辨率一致,单边 `-1` 会让每张图
  ///   按各自宽高比缩放、分辨率不一,报 "Input link parameters do not
  ///   match"(首图尺寸未知时退化为 -1 等比,尽力而为);
  /// - 末尾恒接 `setsar=1`:concat 校验各输入 SAR,不同宽高比的图片
  ///   scale 后 SAR 不一致会报错(已真机实证 ffmpeg 8),setsar=1 统一归一。
  String _perInputChain(GifSetting setting, ImageGifSource source) {
    final fps = _formatFps(setting.fps);
    var width = setting.width;
    var height = setting.height;
    final knownSource = source.width > 0 && source.height > 0;
    if (width == 0 && height == 0 && knownSource) {
      width = source.width;
      height = source.height;
    } else if (width > 0 && height == 0 && knownSource) {
      height = math.max(1, (width * source.height / source.width).round());
    } else if (height > 0 && width == 0 && knownSource) {
      width = math.max(1, (height * source.width / source.height).round());
    }
    final scale = (width > 0 || height > 0)
        ? ',scale=${width > 0 ? width : -1}:'
              '${height > 0 ? height : -1}:flags=lanczos'
        : '';
    return 'fps=$fps$scale,setsar=1';
  }

  /// 裁剪参数(`-ss`/`-to` 前置在 `-i` 前)。
  ///
  /// [end] 为 [Duration.zero] 时省略 `-to`(时长未知 → 输出全片)。
  List<String> _trimArgs(GifSetting setting, Duration end, String inputPath) {
    return [
      '-ss',
      formatFfmpegTime(setting.start),
      if (end > Duration.zero) ...['-to', formatFfmpegTime(end)],
      '-i',
      inputPath,
    ];
  }

  /// 滤镜链前缀(`fps` 恒在,`scale` 按宽高组合追加,§8.3.2 顺序契约)。
  ///
  /// 组合语义:宽高都 0 = 原图(无 scale);单边指定 = 另一边 -1 等比;
  /// 双边指定 = 精确尺寸(允许变形)。
  String _filterChain(GifSetting setting) {
    final fps = _formatFps(setting.fps);
    final scale = (setting.width > 0 || setting.height > 0)
        ? ',scale=${setting.width > 0 ? setting.width : -1}:'
              '${setting.height > 0 ? setting.height : -1}:flags=lanczos'
        : '';
    return 'fps=$fps$scale';
  }

  /// 整数值 fps 不带小数点(15.0 → "15"),非整数原样(29.97 → "29.97")。
  String _formatFps(double fps) {
    return fps == fps.roundToDouble() ? fps.toInt().toString() : fps.toString();
  }
}

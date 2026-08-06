import 'dart:math' as math;

import '../../../core/utils/duration_format.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/per_image_control.dart';
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

  /// 进度百分比分母 = 输出时长 `(裁剪时长) / 播放速度`
  /// (setpts 压缩/拉伸输出时间轴,encode 遍 out_time_us 沿输出轴增长),
  /// 供 [ProgressParser] 计算百分比(§8.3.3);负值钳制为 0。
  Duration progressDenominator(GifSetting setting, VideoInfo video) {
    final d = (setting.end ?? video.duration) - setting.start;
    if (d.isNegative) return Duration.zero;
    return _scaledDuration(d, setting.playbackSpeed);
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
    final canvas = _canvasSize(setting, source);
    final stages = [
      for (var i = 0; i < n; i++)
        '[$i:v]${_perImageChain(setting, source, i, canvas: canvas)}[s$i]',
    ].join(';');
    final labels = [for (var i = 0; i < n; i++) '[s$i]'].join();
    // 播放速度在 concat 后整体 setpts(帧数不变、时间轴缩放,逐图输入
    // `-t` 不动 → 无掉帧);speed=1.0 无后缀,链内 [vout] 保持原名
    final speed = _speedFilterArgs(setting);
    final concatChain =
        '$stages;${labels}concat=n=$n:v=1:a=0[vout]'
        '${speed.isEmpty ? '' : '$speed[vout]'}';
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

  /// 图片模式进度百分比分母 = 总输出时长 `N × 每图时长 ÷ 播放速度`
  /// (encode 遍 out_time_us 沿 concat → setpts 后的输出时间轴增长)。
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

  /// 统一输出画布尺寸(concat 要求各输入分辨率一致;越界容错见契约)。
  ///
  /// 规则:表单宽高双边指定 → 画布 = 指定尺寸(含变形,画布语义);
  /// 均 0 → 首图尺寸;仅单边 → 另一侧按首图宽高比推算;首图尺寸未知
  /// → null(退化,见 [_perImageChain])。
  ({int width, int height})? _canvasSize(
    GifSetting setting,
    ImageGifSource source,
  ) {
    final w = setting.width;
    final h = setting.height;
    if (w > 0 && h > 0) return (width: w, height: h);
    final sw = source.width;
    final sh = source.height;
    if (sw <= 0 || sh <= 0) return null;
    if (w > 0) return (width: w, height: math.max(1, (w * sh / sw).round()));
    if (h > 0) return (width: math.max(1, (h * sw / sh).round()), height: h);
    return (width: sw, height: sh);
  }

  /// 图片模式单输入滤镜链:`fps=F` 恒在,`setsar=1` 兜底(concat 校验
  /// 各输入 SAR,不同宽高比图片 scale 后 SAR 不一致会报错,已实证)。
  ///
  /// **画布已知(正常路径,修复"所有图强制 scale 到首图尺寸 → 不同比例
  /// 图被扭曲"的 BUG)**:
  /// - 未精细控制([PerImageControl] 为 null 或 [PerImageControl.isDefault]):
  ///   `scale=CW:CH:force_original_aspect_ratio=decrease`(保持比例 contain
  ///   填满画布,小图放大、大图缩小,一律不扭曲)→ `format=rgba` →
  ///   透明 pad 居中(居中表达式 (ow-iw)/2);pad 对无 alpha 输入不产生
  ///   alpha 通道,必须先 format=rgba,否则透明色变不透明黑(已实证);
  /// - 精细控制:先按控制 scale(双边 = 精确尺寸,遵守用户决定允许变形;
  ///   单边/倍率 = 等比),再 `scale=min(iw\\,CW):min(ih\\,CH):
  ///   force_original_aspect_ratio=decrease` 钳制链 —— 盒子每维 ≤ 输入
  ///   (只缩不放大),控制目标不超画布时无操作原样显示,超出时按目标
  ///   比例缩到画布内,再透明 pad。每张图独立,未控制图不受影响。
  ///
  /// **画布未知(首图尺寸未知,仅历史重转兜底)**:仅控制 scale 等比
  /// (无 pad 无钳制),未控制则原样 `fps=F,setsar=1`。
  String _perImageChain(
    GifSetting setting,
    ImageGifSource source,
    int index, {
    required ({int width, int height})? canvas,
  }) {
    final fps = _formatFps(setting.fps);
    final control = source.controlAt(index);
    final hasControl = control != null && !control.isDefault;
    final canvasSize = canvas;
    if (canvasSize == null) {
      final controlScale = hasControl ? _controlScaleArgs(control) : null;
      return 'fps=$fps${controlScale != null ? ',$controlScale' : ''},setsar=1';
    }
    final cw = canvasSize.width;
    final ch = canvasSize.height;
    final pad =
        'format=rgba,pad=$cw:$ch:(ow-iw)/2:(oh-ih)/2:'
        'color=0x00000000,setsar=1';
    if (!hasControl) {
      return 'fps=$fps,scale=$cw:$ch:flags=lanczos:'
          'force_original_aspect_ratio=decrease,$pad';
    }
    final controlScale = _controlScaleArgs(control);
    // min 钳制链:表达式内逗号须转义 \,(Dart 串内写 \\,)
    return 'fps=$fps,$controlScale,'
        'scale=min(iw\\,$cw):min(ih\\,$ch):flags=lanczos:'
        'force_original_aspect_ratio=decrease,$pad';
  }

  /// 精细化控制的目标 scale 滤镜串(等比用 iw/ih 表达式,双边为精确
  /// 尺寸允许变形 —— 遵守用户决定;单边另一侧按该图自身比例推导)。
  String _controlScaleArgs(PerImageControl control) {
    final w = control.width;
    final h = control.height;
    if (w > 0 && h > 0) return 'scale=$w:$h:flags=lanczos';
    if (w > 0) return 'scale=$w:-1:flags=lanczos';
    if (h > 0) return 'scale=-1:$h:flags=lanczos';
    final m = _formatFps(control.scaleMultiplier);
    return 'scale=iw*$m:ih*$m:flags=lanczos';
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
  /// 双边指定 = 精确尺寸(允许变形)。播放速度在链尾追加 setpts。
  String _filterChain(GifSetting setting) {
    final fps = _formatFps(setting.fps);
    final scale = (setting.width > 0 || setting.height > 0)
        ? ',scale=${setting.width > 0 ? setting.width : -1}:'
              '${setting.height > 0 ? setting.height : -1}:flags=lanczos'
        : '';
    return 'fps=$fps$scale${_speedFilterArgs(setting)}';
  }

  /// 播放速度滤镜参数:非 1.0 时返回 `,setpts=PTS/<speed>`(帧数不变、
  /// 输出时间轴等比缩放;加速 → 总时长缩短,慢放 → 拉长);1.0(默认)
  /// 返回空串不注入,既有命令快照保持不变。
  String _speedFilterArgs(GifSetting setting) {
    final speed = setting.playbackSpeed;
    if ((speed - 1.0).abs() < 1e-9) return '';
    return ',setpts=PTS/${_formatFps(speed)}';
  }

  /// 时长按播放速度缩放(输出时间轴 = 源时长 / speed)。
  Duration _scaledDuration(Duration d, double speed) {
    return Duration(microseconds: (d.inMicroseconds / speed).round());
  }

  /// 整数值 fps 不带小数点(15.0 → "15"),非整数原样(29.97 → "29.97")。
  String _formatFps(double fps) {
    return fps == fps.roundToDouble() ? fps.toInt().toString() : fps.toString();
  }
}

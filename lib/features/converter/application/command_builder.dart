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
    final inputs = _imageInputArgs(setting, source.paths);
    final canvas = _canvasSize(setting, source);
    final stages = [
      for (var i = 0; i < n; i++)
        '[$i:v]${_perImageChain(setting, source, i, canvas: canvas)}[s$i]',
    ].join(';');
    final labels = [for (var i = 0; i < n; i++) '[s$i]'].join();
    // 播放速度在 concat 后整体 setpts(帧数不变、时间轴缩放,逐图输入
    // `-t` 不动 → 无掉帧)。**标签规则**:concat 输出显式加 [vout] 后链内
    // 隐式连接失效(下游 setpts 输入悬空 → 滤镜图绑定失败 exit 234,已
    // 实证),因此 speed≠1 时 concat 不加标签、由链尾 setpts 统一加 [vout];
    // speed=1.0 保持 `concat=...[vout]` 原样。
    final speed = _speedFilterArgs(setting);
    final concatChain =
        '$stages;${labels}concat=n=$n:v=1:a=0'
        '${speed.isEmpty ? '[vout]' : '$speed[vout]'}';
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

  /// 分段路径:单段编码命令(图片子集 → ffv1 无损中间片)。
  ///
  /// 大图集合(N > [kSegmentModeThreshold])由服务层按 [segmentSizes]
  /// 切段后逐段调用本方法,每段独立执行(段内峰值内存与单次运行一致,
  /// 消除 100 张 2048×2048 的 2-4GB 原生 RSS → 闪退根因)。
  /// 段内**无调色板、无 setpts**:段输出为原始时间轴(时间长度 =
  /// 段图数 × 每图实际段长),最终 concat 统一 setpts(播放速度)。
  /// 滤镜链与 [buildFromImages] 逐字节一致(同画布 → 各段分辨率/
  /// SAR/像素格式一致,最终 concat 校验通过)。
  GifCommand buildImageSegment({
    required GifSetting setting,
    required ImageGifSource source,
    required int start,
    required int count,
    required String workDir,
    required String segmentPath,
  }) {
    final paths = source.paths.sublist(start, start + count);
    final inputs = _imageInputArgs(setting, paths);
    final canvas = _canvasSize(setting, source);
    // 段内输入编号从 0 起,精细控制按全局下标取(start + i)
    final stages = [
      for (var i = 0; i < count; i++)
        '[$i:v]${_perImageChain(setting, source, start + i, canvas: canvas)}[s$i]',
    ].join(';');
    final labels = [for (var i = 0; i < count; i++) '[s$i]'].join();
    final concatChain = '$stages;${labels}concat=n=$count:v=1:a=0[vout]';
    return GifCommand(
      args: [
        ...inputs,
        '-filter_complex',
        concatChain,
        '-map',
        '[vout]',
        '-c:v',
        'ffv1',
        '-f',
        'matroska',
        '-progress',
        'pipe:1',
        '-y',
        segmentPath,
      ],
      label: GifCommand.kSegmentLabel,
    );
  }

  /// 分段路径:段中间片 → 最终 GIF 的命令列表(与 [buildFromImages] 的
  /// palette/encode 结构对齐,输入换成各段 mkv)。
  ///
  /// - 段输入分辨率/SAR/fps 一致(同画布同参数)→ concat 直接校验通过;
  /// - 播放速度统一在 concat 后 setpts(与单次运行语义一致);
  /// - palette 模式:palettegen 遍无 `-progress`(进度由编排层冻结),
  ///   paletteuse 遍带 `-progress pipe:1`;单遍:encode 一条带进度。
  List<GifCommand> buildFromSegments({
    required GifSetting setting,
    required List<String> segmentPaths,
    required String workDir,
    required String outputPath,
    required bool usePalette,
  }) {
    final n = segmentPaths.length;
    final inputs = [
      for (final p in segmentPaths) ...['-i', p],
    ];
    // 段流直接 concat(无逐段滤镜),播放速度链尾统一 setpts(规则同
    // buildFromImages:speed≠1 时 concat 不加标签、由 setpts 加 [vout])
    final speed = _speedFilterArgs(setting);
    final concatChain =
        '${[for (var i = 0; i < n; i++) '[$i:v]'].join()}'
        'concat=n=$n:v=1:a=0'
        '${speed.isEmpty ? '[vout]' : '$speed[vout]'}';
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
      // 第一遍:全局调色板(无 -progress;进度由编排层冻结在段编码后)
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

  /// 分段路径:单段进度百分比分母 = `段图数 × 每图实际段长`
  /// (段轴无 setpts,out_time_us 沿段原始时间轴增长)。
  Duration segmentProgressDenominator(GifSetting setting, int count) {
    return Duration(
      microseconds: setting.quantizedFrameDuration.inMicroseconds * count,
    );
  }

  /// 图片输入参数序列(每图 `-loop 1 -t D -framerate F -i path`)。
  List<String> _imageInputArgs(GifSetting setting, List<String> paths) {
    final d = formatFfmpegTime(setting.effectiveFrameDuration);
    final f = _formatFps(setting.fps);
    return [
      for (final path in paths) ...[
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

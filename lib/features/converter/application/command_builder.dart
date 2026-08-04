import '../../../core/utils/duration_format.dart';
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

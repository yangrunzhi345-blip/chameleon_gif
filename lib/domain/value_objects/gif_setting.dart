import 'package:freezed_annotation/freezed_annotation.dart';

part 'gif_setting.freezed.dart';
part 'gif_setting.g.dart';

/// GIF 输出参数(视频 + 图片合成共用;palette/图片时长已落地,V2 追加
/// dithering/色彩数/镜像/旋转等字段;新增字段一律带默认值,保证老历史
/// JSON 可读,见 docs/07-数据库设计.md §7.5)。
@freezed
abstract class GifSetting with _$GifSetting {
  /// freezed 自定义 getter 要求私有构造(见 effectiveFrameDuration)。
  const GifSetting._();

  const factory GifSetting({
    /// 输出帧率(1–60)
    @Default(15.0) double fps,

    /// 输出宽度(0 = 原图等比,默认)
    @Default(0) int width,

    /// 输出高度(0 = 原图等比,默认;与宽度同时指定时按指定尺寸输出)
    @Default(0) int height,

    /// 输出起点(相对源视频)
    @Default(Duration.zero) Duration start,

    /// 输出终点(默认取源视频时长,由导入时填充)
    Duration? end,

    /// 循环次数(0 = 无限循环)
    @Default(0) int loop,

    /// 图片模式:每张图片停留时长(毫秒);null = 由 [fps] 推导(每图一帧)。
    /// 视频模式不读取该字段。
    int? frameDurationMs,

    /// 图片模式:质量开关;true = 调色板两遍(高质,默认),false = 标准单遍。
    /// 视频模式不读取该字段(视频 UI 无质量开关,恒走两遍)。
    @Default(true) bool usePalette,

    /// 输出等比缩放倍数(0.5/0.75/1/1.5/2/3;1.0 = 不缩放,默认)。
    ///
    /// 源尺寸已知时选倍数会联动落成具体 width/height;本字段是
    /// "偏好/展开语义":批量入队时若 width==height==0 且 m!=1.0,
    /// 按各视频自身尺寸 × m 展开(见 scale_multiplier.dart)。
    @Default(1.0) double scaleMultiplier,

    /// 播放速度(0.25–4:0.25/0.5 慢放,1.0 正常,≥2 加速;默认 1.0)。
    ///
    /// 命令侧经滤镜链 `setpts=PTS/<speed>` 实现:帧数不变、输出时间轴
    /// 等比缩放(加速 → 总时长缩短,慢放 → 拉长);视频模式裁剪
    /// `-ss`/`-to` 作用于源时间轴,不受速度影响;1.0 不注入滤镜(快照不变)。
    @Default(1.0) double playbackSpeed,
  }) = _GifSetting;

  factory GifSetting.fromJson(Map<String, dynamic> json) =>
      _$GifSettingFromJson(json);

  /// 图片模式:每张图片的实际输出时长。
  ///
  /// [frameDurationMs] 显式指定时原样返回;否则由帧率推导 1000/fps
  /// (每图一帧,至少 1ms)。纯 Dart getter,可独立单测。
  Duration get effectiveFrameDuration {
    final ms =
        frameDurationMs ??
        Duration(microseconds: (1e6 / fps).round()).inMilliseconds;
    return Duration(milliseconds: ms < 1 ? 1 : ms);
  }

  /// 图片模式每图**实际**段长(按整帧量化,与 ffmpeg 行为一致)。
  ///
  /// ffmpeg 图片输入 `-loop 1 -t D -framerate F` 按整帧读取:PTS < D 的
  /// 帧全部读入,段内帧数 = `ceil(D×F/1000)`,实际段长 = 帧数/F。
  /// 例:每图 100ms @ 15fps → 2 帧 → 133ms(而非 100ms);每图 1000ms →
  /// 15 帧 → 1000ms。低于 2 帧间隔的时长无法精确表达,属帧率语义固有
  /// 边界(见 CLAUDE.md §6.4),进度分母/UI 总时长均以此为准,避免与
  /// 产物时长偏差。
  Duration get quantizedFrameDuration {
    final frames = (effectiveFrameDuration.inMilliseconds * fps / 1000).ceil();
    return Duration(microseconds: (frames / fps * 1e6).round());
  }
}

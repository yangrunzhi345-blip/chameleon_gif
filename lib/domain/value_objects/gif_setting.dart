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
}

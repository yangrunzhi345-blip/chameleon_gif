import 'package:freezed_annotation/freezed_annotation.dart';

part 'gif_setting.freezed.dart';
part 'gif_setting.g.dart';

/// GIF 输出参数(MVP 子集;V2 追加 palette/dithering/色彩数/镜像/旋转等字段,
/// 新增字段一律带默认值,保证老历史 JSON 可读,见 docs/07-数据库设计.md §7.5)。
@freezed
abstract class GifSetting with _$GifSetting {
  const factory GifSetting({
    /// 输出帧率(1–60)
    @Default(15.0) double fps,

    /// 输出宽度(0 = 原图等比)
    @Default(480) int width,

    /// 输出起点(相对源视频)
    @Default(Duration.zero) Duration start,

    /// 输出终点(默认取源视频时长,由导入时填充)
    Duration? end,

    /// 循环次数(0 = 无限循环)
    @Default(0) int loop,
  }) = _GifSetting;

  factory GifSetting.fromJson(Map<String, dynamic> json) =>
      _$GifSettingFromJson(json);
}

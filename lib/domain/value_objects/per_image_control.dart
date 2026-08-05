import 'package:freezed_annotation/freezed_annotation.dart';

part 'per_image_control.freezed.dart';
part 'per_image_control.g.dart';

/// 单张图片的精细化控制参数(图片模式,与 [GifSetting] 并列的每图覆盖)。
///
/// 语义(docs/08-FFmpeg设计.md 图片节,精细控制):
/// - `width`/`height` 为目标框:双边指定时**遵守用户决定,允许变形**
///   (其余图不受影响);单边指定时另一侧按该图自身宽高比等比推导;
/// - `scaleMultiplier` 为以该图自身尺寸为基准的等比倍数,**仅当宽高均 0
///   时生效**(1.0 = 不缩放);
/// - 未精细控制的图片一律保持比例 + 透明填充 pad,不扭曲;
/// - 目标超出画布(全局表单宽高或首图尺寸)时钳制到画布内。
///
/// [isDefault] 为真表示未做任何操作(倍率 1、宽高均 0),不产生任何效果;
/// 序列化随任务/历史持久化(Isar JSON 列),老数据缺列时默认 null。
@freezed
abstract class PerImageControl with _$PerImageControl {
  const PerImageControl._();

  const factory PerImageControl({
    /// 等比缩放倍数(仅宽高均 0 时生效;0.1–4,默认 1.0)
    @Default(1.0) double scaleMultiplier,

    /// 目标宽度(0 = 不指定,按自身比例;默认)
    @Default(0) int width,

    /// 目标高度(0 = 不指定,按自身比例;默认)
    @Default(0) int height,
  }) = _PerImageControl;

  factory PerImageControl.fromJson(Map<String, dynamic> json) =>
      _$PerImageControlFromJson(json);

  /// 是否全默认(未做任何操作;1.0 用 epsilon 防 JSON 浮点噪声)。
  bool get isDefault =>
      width == 0 && height == 0 && (scaleMultiplier - 1.0).abs() <= 1e-6;

  /// 非默认字段摘要(UI 齿轮左侧信息文本,如 "缩放倍率:2 宽度:480")。
  String get summary {
    final parts = <String>[];
    if ((scaleMultiplier - 1.0).abs() > 1e-6) {
      final m = scaleMultiplier;
      parts.add('缩放倍率:${m == m.roundToDouble() ? m.toInt() : m}');
    }
    if (width != 0) parts.add('宽度:$width');
    if (height != 0) parts.add('高度:$height');
    return parts.join(' ');
  }
}

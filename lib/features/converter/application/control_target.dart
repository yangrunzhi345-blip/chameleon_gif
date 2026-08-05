import 'dart:math' as math;

import '../../../domain/value_objects/per_image_control.dart';

/// 精细控制的该图最终显示尺寸(纯函数,预览与命令构造同规则)。
///
/// 规则与 [GifCommandBuilder] 图片链一致:
/// - 双边指定 → 精确尺寸(遵守用户决定,**允许变形**);
/// - 仅宽/仅高 → 另一侧按该图自身宽高比等比推导;
/// - 仅倍数(宽高均 0)→ 以该图自身尺寸 × 倍数等比;
/// - 目标超出画布 → contain 钳制到画布内(保持目标比例,只缩不放大)。
///
/// 注意:预览近似用 round,命令构造走 ffmpeg 表达式,像素级差异 ≤1px;
/// 该函数仅供 UI 展示"最终呈现比例",不参与命令生成。
({int width, int height}) controlTarget({
  required PerImageControl control,
  required int sourceWidth,
  required int sourceHeight,
  required int canvasWidth,
  required int canvasHeight,
}) {
  final w = control.width;
  final h = control.height;
  int tw;
  int th;
  if (w > 0 && h > 0) {
    tw = w;
    th = h;
  } else if (w > 0) {
    tw = w;
    th = math.max(1, (w * sourceHeight / sourceWidth).round());
  } else if (h > 0) {
    tw = math.max(1, (h * sourceWidth / sourceHeight).round());
    th = h;
  } else {
    tw = math.max(1, (sourceWidth * control.scaleMultiplier).round());
    th = math.max(1, (sourceHeight * control.scaleMultiplier).round());
  }
  final factor = math.min(1.0, math.min(canvasWidth / tw, canvasHeight / th));
  return (width: (tw * factor).round(), height: (th * factor).round());
}

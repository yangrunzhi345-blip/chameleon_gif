/// 区域遮罩拖拽的纯 Dart 数学与命令装配(可独立快照单测)。
///
/// 服务 X11/Windows 的「框选录制范围」全屏截图遮罩(见
/// presentation/overlay_region_picker.dart):拖拽起止点 → 屏幕物理像素
/// 矩形;物理矩形 → ffmpeg 单帧截图命令。坐标映射前提:全屏窗口
/// 逻辑坐标 × DPR = 屏幕物理像素(窗口所在显示器,主屏原点假设)。
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'record_command_builder.dart' show RecordCommandKind;
import 'region_picker.dart' show RegionGeometry;

/// 拖拽选区解析:归一化 → 越界钳制 → 误触退化 → 物理像素取整。
///
/// [start]/[end] 为拖拽起止点(遮罩窗口内逻辑坐标);越界按
/// [logicalSize] 钳制;两轴位移均小于 [minDragLogicalPx](默认 4 逻辑
/// 像素,防误触)→ 返回 null;结果经 [dpr] 换算为物理像素,宽高
/// 下限 1(保证 ffmpeg `-video_size` 合法)。
RegionGeometry? resolveDragRegion({
  required Offset start,
  required Offset end,
  required Size logicalSize,
  required double dpr,
  double minDragLogicalPx = 4,
}) {
  final left = math.min(start.dx, end.dx).clamp(0.0, logicalSize.width);
  final right = math.max(start.dx, end.dx).clamp(0.0, logicalSize.width);
  final top = math.min(start.dy, end.dy).clamp(0.0, logicalSize.height);
  final bottom = math.max(start.dy, end.dy).clamp(0.0, logicalSize.height);
  if (right - left < minDragLogicalPx && bottom - top < minDragLogicalPx) {
    return null; // 误触(点按/微位移):视为取消
  }
  final x = (left * dpr).round();
  final y = (top * dpr).round();
  return RegionGeometry(
    x: x,
    y: y,
    width: math.max(1, (right * dpr).round() - x),
    height: math.max(1, (bottom * dpr).round() - y),
  );
}

/// 单帧屏幕截图命令(遮罩背景;`-hide_banner -loglevel error`,输出 PNG)。
///
/// [physicalRect] 为物理像素矩形;[kind] 仅接受 [RecordCommandKind.x11grab]
/// 与 [gdigrab](wfRecorder 无单帧截图语义,传之抛错);[display] 仅
/// x11grab 使用(如 ':1')。返回 [Process.run] 参数数组,不经 shell。
List<String> buildSingleFrameCaptureArgs({
  required Rect physicalRect,
  required RecordCommandKind kind,
  required String outputPath,
  String? display,
}) {
  final size = '${physicalRect.width.round()}x${physicalRect.height.round()}';
  switch (kind) {
    case RecordCommandKind.x11grab:
      final dpy = display;
      assert(dpy != null && dpy.isNotEmpty, 'x11grab 需要 DISPLAY 值');
      return [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'x11grab',
        '-video_size',
        size,
        '-i',
        '$dpy+${physicalRect.left.round()}+${physicalRect.top.round()}',
        '-frames:v',
        '1',
        '-y',
        outputPath,
      ];
    case RecordCommandKind.gdigrab:
      return [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'gdigrab',
        '-offset_x',
        '${physicalRect.left.round()}',
        '-offset_y',
        '${physicalRect.top.round()}',
        '-video_size',
        size,
        '-i',
        'desktop',
        '-frames:v',
        '1',
        '-y',
        outputPath,
      ];
    case RecordCommandKind.wfRecorder:
      throw ArgumentError('wfRecorder 无单帧截图语义(遮罩仅 X11/Windows)');
  }
}

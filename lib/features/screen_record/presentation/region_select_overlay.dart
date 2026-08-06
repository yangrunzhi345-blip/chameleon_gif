/// 区域框选遮罩(全屏;X11/Windows「框选录制范围」交互面)。
///
/// 背景为屏幕截图([pngBytes],物理像素经 drawImageRect 映射到窗口逻辑
/// 矩形;null/解码失败回退纯深色背景,拖拽不受影响)。交互:
/// - 拖拽(松开)→ [Navigator.pop] 选区 [RegionGeometry](屏幕物理像素);
/// - 点按/Esc → pop null(取消)。
/// 坐标映射:窗口逻辑坐标 × [dpr] = 屏幕物理像素(见 OverlayRegionPicker)。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/region_overlay_math.dart';

/// 全屏遮罩页(经 rootNavigatorKey push,非路由表成员)。
class RegionSelectOverlay extends StatefulWidget {
  const RegionSelectOverlay({super.key, required this.dpr, this.pngBytes});

  /// 窗口 devicePixelRatio(与编排器截图参数同源)。
  final double dpr;

  /// 屏幕截图 PNG 字节(物理像素;null → 纯色背景)。
  final Uint8List? pngBytes;

  @override
  State<RegionSelectOverlay> createState() => _RegionSelectOverlayState();
}

class _RegionSelectOverlayState extends State<RegionSelectOverlay> {
  ui.Image? _screenshot;
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  void initState() {
    super.initState();
    final bytes = widget.pngBytes;
    if (bytes != null) {
      ui.decodeImageFromList(bytes, (img) {
        if (mounted) setState(() => _screenshot = img);
      });
    }
  }

  @override
  void dispose() {
    _screenshot?.dispose();
    super.dispose();
  }

  /// 拖拽选区(逻辑坐标,已归一化+钳制);无拖拽 → null。
  Rect? get _selection {
    final start = _dragStart;
    final end = _dragEnd;
    if (start == null || end == null) return null;
    final size = MediaQuery.sizeOf(context);
    final left = math.min(start.dx, end.dx).clamp(0.0, size.width);
    final right = math.max(start.dx, end.dx).clamp(0.0, size.width);
    final top = math.min(start.dy, end.dy).clamp(0.0, size.height);
    final bottom = math.max(start.dy, end.dy).clamp(0.0, size.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // 用底层 Listener 而非 GestureDetector pan:竞技场行为在测试与部分
  // 场景下 down 位置不可靠(实测 onPanStart 起点为首次越过 slop 的
  // move 位置,onPanDown 亦偶失);Listener 的 down/move/up 直接到达,
  // 起点精确。未移动的 down+up → 位移 <4px → resolveDragRegion null → 取消。
  void _onPointerDown(PointerDownEvent e) {
    setState(() {
      _dragStart = e.localPosition;
      _dragEnd = e.localPosition;
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    setState(() => _dragEnd = e.localPosition);
  }

  void _onPointerUp(PointerUpEvent e) {
    final start = _dragStart;
    final end = _dragEnd;
    final geometry = start == null || end == null
        ? null
        : resolveDragRegion(
            start: start,
            end: end,
            logicalSize: MediaQuery.sizeOf(context),
            dpr: widget.dpr,
          );
    Navigator.of(context).pop(geometry);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final selection = _selection;
    final displayGeo = selection == null
        ? null
        : resolveDragRegion(
            start: selection.topLeft,
            end: selection.bottomRight,
            logicalSize: size,
            dpr: widget.dpr,
          );
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _OverlayPainter(
                  screenshot: _screenshot,
                  selection: selection,
                ),
              ),
            ),
            if (_dragStart == null)
              Positioned(
                top: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '拖拽选择录制区域,Esc 取消',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            if (selection != null && displayGeo != null)
              Positioned(
                left: selection.left,
                top: selection.bottom + 6 > size.height - 24
                    ? selection.top - 26
                    : selection.bottom + 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${displayGeo.width}x${displayGeo.height}'
                    '+${displayGeo.x}+${displayGeo.y}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 遮罩绘制:截图背景 → 选区外暗罩(evenOdd 挖洞)→ 选区描边。
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({this.screenshot, this.selection});

  final ui.Image? screenshot;
  final Rect? selection;

  @override
  void paint(Canvas canvas, Size size) {
    final img = screenshot;
    if (img != null) {
      // 截图物理像素 → 窗口逻辑矩形(尺寸一致,dpr>1 时自动缩回)
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.low,
      );
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF1E1E1E),
      );
    }
    final sel = selection;
    if (sel == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      return;
    }
    // 选区外压暗、选区内露出截图(evenOdd 挖洞)
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRect(sel)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      mask,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    // 深色外描边 + 白色内描边(明暗背景均可辨)
    canvas.drawRect(
      sel.inflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black,
    );
    canvas.drawRect(
      sel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.screenshot != screenshot ||
      oldDelegate.selection != selection;
}

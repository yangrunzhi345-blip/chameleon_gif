/// 全屏截图遮罩框选编排(X11/Windows;Wayland 走 slurp,见
/// CompositeRegionPicker)。
///
/// 时序:保存窗口态 → 置顶全屏 → 取全屏矩形(逻辑×DPR=物理) →
/// 隐藏窗口 → ffmpeg 单帧截图 → 显示遮罩(截图背景+拖拽)→ pop 几何;
/// finally 恢复窗口态。截图失败回退纯色背景仍可拖拽;窗口操作异常
/// → 取消(null,与 slurp 取消同语义)。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/logger/app_logger.dart';
import '../application/record_command_builder.dart' show RecordCommandKind;
import '../application/region_overlay_math.dart';
import '../application/region_picker.dart';
import 'region_select_overlay.dart';

/// 窗口控制抽象(测试注入 fake;生产转调 window_manager)。
abstract interface class OverlayWindowController {
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<void> hide();
  Future<void> show();
  Future<void> focus();
  Future<void> setFullScreen(bool isFullScreen);
  Future<bool> isFullScreen();
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop);
  Future<bool> isMaximized();
}

/// 生产实现:转调 window_manager 单例。
class WindowManagerController implements OverlayWindowController {
  const WindowManagerController();

  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<void> setFullScreen(bool isFullScreen) =>
      windowManager.setFullScreen(isFullScreen);

  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop) =>
      windowManager.setAlwaysOnTop(isAlwaysOnTop);

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();
}

/// 截图执行:ffmpeg 单帧 PNG → 字节;null = 失败(遮罩回退纯色背景)。
typedef RegionCaptureRunner = Future<Uint8List?> Function(List<String> args);

/// 全屏截图遮罩框选器(见类注释;装配见 CapturePlatformFactory)。
class OverlayRegionPicker implements RegionPicker {
  OverlayRegionPicker({
    required GlobalKey<NavigatorState> navigatorKey,
    required Directory tempDir,
    required RecordCommandKind kind,
    required AppLogger logger,
    this.display,
    OverlayWindowController? windowController,
    RegionCaptureRunner? captureRunner,
    double Function()? devicePixelRatio,
    this.settleDelay = const Duration(milliseconds: 300),
    this.fullScreenTimeout = const Duration(seconds: 3),
  }) : _navigatorKey = navigatorKey,
       _tempDir = tempDir,
       _kind = kind,
       _logger = logger,
       _window = windowController ?? const WindowManagerController(),
       _captureRunner = captureRunner ?? _captureWithFfmpeg,
       _devicePixelRatio =
           devicePixelRatio ??
           (() => WidgetsBinding
               .instance
               .platformDispatcher
               .views
               .first
               .devicePixelRatio);

  final GlobalKey<NavigatorState> _navigatorKey;
  final Directory _tempDir;
  final RecordCommandKind _kind;
  final AppLogger _logger;

  /// 仅 x11grab 使用(如 ':1')。
  final String? display;

  final OverlayWindowController _window;
  final RegionCaptureRunner _captureRunner;
  final double Function() _devicePixelRatio;

  /// 隐藏窗口 → 截图间的沉降等待(合成器窗口消失时序)。
  final Duration settleDelay;

  /// 全屏状态轮询超时。
  final Duration fullScreenTimeout;

  /// X11/Windows 装配时恒可用(composite 已按会话分流)。
  @override
  bool get isAvailable => true;

  @override
  Future<RegionGeometry?> pick() async {
    final window = _window;
    Rect? originalBounds;
    var wasMaximized = false;
    try {
      // 1. 保存原窗口状态(读取失败则恢复步骤尽力而为)
      try {
        originalBounds = await window.getBounds();
        wasMaximized = await window.isMaximized();
      } on Exception {
        _logger.w('区域框选:窗口状态读取失败,恢复将尽力而为');
      }
      // 2. 置顶全屏(遮罩必须盖住其他窗口)
      await window.setAlwaysOnTop(true);
      await window.setFullScreen(true);
      if (!await _waitFor(window.isFullScreen, fullScreenTimeout)) {
        _logger.w('区域框选:全屏超时,取消');
        return null;
      }
      // 3. 全屏矩形 = 窗口所在显示器(逻辑);×DPR = 物理(截图/选区基准)
      final fullRect = await window.getBounds();
      // 4. 隐藏 → 沉降 → 截图(避免截到本应用窗口)
      await window.hide();
      await Future<void>.delayed(settleDelay);
      final pngBytes = await _capture(fullRect);
      // 5. 显示遮罩并确认仍全屏(部分 WM 隐藏/显示后丢全屏态)
      await window.show();
      await window.focus();
      if (!await window.isFullScreen()) {
        await window.setFullScreen(true);
        await _waitFor(window.isFullScreen, fullScreenTimeout);
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _logger.w('区域框选:导航器未就绪,取消');
        return null;
      }
      // 6. 推遮罩;pop 结果(选区几何 / null 取消)即返回值
      return await navigator.push<RegionGeometry>(
        MaterialPageRoute(
          builder: (_) =>
              RegionSelectOverlay(dpr: _devicePixelRatio(), pngBytes: pngBytes),
        ),
      );
    } on Exception catch (e) {
      _logger.e('区域框选失败', error: e);
      return null;
    } finally {
      // 7. 恢复窗口态(取消/确认/异常统一路径)
      await _restore(window, originalBounds, wasMaximized);
    }
  }

  /// 截全屏一帧(临时 PNG,读后即删);失败 → null(遮罩纯色回退)。
  Future<Uint8List?> _capture(Rect logicalFullRect) async {
    final dpr = _devicePixelRatio();
    final physical = Rect.fromLTWH(
      (logicalFullRect.left * dpr).roundToDouble(),
      (logicalFullRect.top * dpr).roundToDouble(),
      (logicalFullRect.width * dpr).roundToDouble(),
      (logicalFullRect.height * dpr).roundToDouble(),
    );
    final args = buildSingleFrameCaptureArgs(
      physicalRect: physical,
      kind: _kind,
      display: display,
      outputPath: '${_tempDir.path}/chameleon_gif_region_$pid.png',
    );
    final bytes = await _captureRunner(args);
    if (bytes == null) {
      _logger.w('区域框选:截图失败,遮罩回退纯色背景');
    }
    return bytes;
  }

  /// 恢复窗口:退全屏 → 去置顶 → 非最大化时还原原矩形。
  Future<void> _restore(
    OverlayWindowController window,
    Rect? originalBounds,
    bool wasMaximized,
  ) async {
    try {
      await window.setFullScreen(false);
      await _waitFor(
        () async => !await window.isFullScreen(),
        fullScreenTimeout,
      );
      await window.setAlwaysOnTop(false);
      if (!wasMaximized && originalBounds != null) {
        await window.setBounds(originalBounds);
      }
    } on Exception catch (e) {
      _logger.w('区域框选:窗口状态恢复失败', error: e);
    }
  }

  /// 轮询 [probe] 至 true 或超时。
  Future<bool> _waitFor(Future<bool> Function() probe, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await probe()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return false;
  }

  /// 生产截图:ffmpeg 单帧 → 读临时 PNG → 清理(输出路径取参数末位)。
  static Future<Uint8List?> _captureWithFfmpeg(List<String> args) async {
    final result = await Process.run('ffmpeg', args);
    if (result.exitCode != 0) return null;
    final out = File(args.last);
    try {
      final bytes = await out.readAsBytes();
      return bytes;
    } on Exception {
      return null;
    } finally {
      try {
        out.deleteSync();
      } on Exception {
        // 临时文件清理失败不影响流程(系统临时目录)
      }
    }
  }
}

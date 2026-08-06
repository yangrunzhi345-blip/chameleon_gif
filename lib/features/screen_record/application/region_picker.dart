import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 屏幕区域几何(与 RecordParams.regionX/Y/Width/Height 对应)。
class RegionGeometry {
  const RegionGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

/// 解析 slurp 输出(Wayland 交互式选区工具):
/// 默认/`-f "%wx%h+%x+%y"` 输出 `WxH+X+Y`;非法输入 → null。
RegionGeometry? parseSlurpGeometry(String text) {
  final m = RegExp(r'^(\d+)x(\d+)\+(\d+)\+(\d+)$').firstMatch(text.trim());
  if (m == null) return null;
  return RegionGeometry(
    width: int.parse(m.group(1)!),
    height: int.parse(m.group(2)!),
    x: int.parse(m.group(3)!),
    y: int.parse(m.group(4)!),
  );
}

/// 区域框选器契约(UI 侧仅依赖此接口,平台策略由装配层注入)。
abstract interface class RegionPicker {
  /// 当前环境是否可交互框选(不可用时 UI 回退数字输入)。
  bool get isAvailable;

  /// 阻塞至用户操作:拖拽确认 → 选区几何;取消/失败 → null。
  Future<RegionGeometry?> pick();
}

/// 区域框选策略组合(按会话类型转发):
/// Wayland → [ScreenRegionPicker](slurp 交互选区);
/// 其他(X11/Windows)→ overlay 实现([OverlayRegionPicker],装配层注入)。
class CompositeRegionPicker implements RegionPicker {
  CompositeRegionPicker({
    required this.wayland,
    required ScreenRegionPicker slurpPicker,
    required RegionPicker overlayPicker,
  }) : _slurp = slurpPicker,
       _overlay = overlayPicker;

  /// 当前会话是否为 Wayland(决定转发目标)。
  final bool wayland;

  final ScreenRegionPicker _slurp;
  final RegionPicker _overlay;

  RegionPicker get _active => wayland ? _slurp : _overlay;

  @override
  bool get isAvailable => _active.isAvailable;

  @override
  Future<RegionGeometry?> pick() => _active.pick();
}

/// 屏幕区域交互式框选(Wayland slurp:真实屏幕上鼠标拖拽选区)。
///
/// 阻塞至用户操作:拖拽确认(输出几何)或取消(退出码非 0 → null)。
/// 仅 Wayland + slurp 可用时有效([isAvailable]);X11/Windows 走
/// overlay 实现(见 CompositeRegionPicker)。
class ScreenRegionPicker implements RegionPicker {
  ScreenRegionPicker({
    Future<Process> Function(List<String> args)? startProcess,
    String? sessionType,
    bool Function(String name)? toolExists,
  }) : _startProcess = startProcess ?? _run,
       _sessionType = sessionType ?? Platform.environment['XDG_SESSION_TYPE'],
       _toolExists = toolExists ?? _which;

  final Future<Process> Function(List<String> args) _startProcess;
  final String? _sessionType;
  final bool Function(String name) _toolExists;

  /// slurp 可用:Wayland 会话且二进制存在。
  @override
  bool get isAvailable {
    if (_sessionType?.toLowerCase() != 'wayland') return false;
    try {
      return _toolExists('slurp');
    } on ProcessException {
      return false;
    }
  }

  /// 启动 slurp 交互框选,返回选区几何;取消/失败 → null。
  @override
  Future<RegionGeometry?> pick() async {
    final process = await _startProcess(['slurp', '-f', '%wx%h+%x+%y']);
    // slurp 的 stdin 非 TTY 时进入"预定义框读取"模式(main.c 的
    // getline 循环阻塞读框,见 `-r` 选择框功能);应用内启动 stdin 为
    // 管道 → 立即关闭令 EOF,否则 slurp 挂起在读取、遮罩永不显示
    // (实测:niri 终端 TTY 正常、管道挂起、EOF 恢复显示)。
    process.stdin.close();
    final output = await process.stdout
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 60));
    final code = await process.exitCode;
    if (code != 0 || output.trim().isEmpty) return null;
    return parseSlurpGeometry(output);
  }

  static Future<Process> _run(List<String> args) =>
      Process.start(args.first, args.sublist(1));

  static bool _which(String name) {
    final result = Process.runSync('which', [name]);
    return result.exitCode == 0;
  }
}

/// 区域框选器注入点(测试 override fake;生产由 CapturePlatformFactory
/// 按平台装配 CompositeRegionPicker)。
final screenRegionPickerProvider = Provider<RegionPicker>(
  (ref) => ScreenRegionPicker(),
);

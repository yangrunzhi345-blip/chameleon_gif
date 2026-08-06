import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/screen_record/application/region_picker.dart';

/// slurp 输出解析 + 区域框选器(真实进程注入)。
void main() {
  group('parseSlurpGeometry', () {
    test('WxH+X+Y 解析', () {
      final g = parseSlurpGeometry('640x480+100+50');
      expect(g, isNotNull);
      expect(g!.width, 640);
      expect(g.height, 480);
      expect(g.x, 100);
      expect(g.y, 50);
    });

    test('全屏尺寸(0+0)', () {
      final g = parseSlurpGeometry('1920x1080+0+0');
      expect(g!.x, 0);
      expect(g.y, 0);
      expect(g.width, 1920);
      expect(g.height, 1080);
    });

    test('非法/空 → null', () {
      expect(parseSlurpGeometry(''), isNull);
      expect(parseSlurpGeometry('abc'), isNull);
      expect(parseSlurpGeometry('640x480'), isNull, reason: '缺偏移');
      expect(parseSlurpGeometry('640x480+100+50\n'), isNotNull, reason: '容忍换行');
    });
  });

  group('ScreenRegionPicker', () {
    test('非 Wayland 会话 → 不可用', () {
      final picker = ScreenRegionPicker(
        sessionType: 'x11',
        toolExists: (_) => true,
      );
      expect(picker.isAvailable, isFalse);
    });

    test('Wayland 但 slurp 缺失 → 不可用', () {
      final picker = ScreenRegionPicker(
        sessionType: 'wayland',
        toolExists: (_) => false,
      );
      expect(picker.isAvailable, isFalse);
    });

    test('Wayland + slurp → 可用;pick 解析输出', () async {
      final picker = ScreenRegionPicker(
        sessionType: 'wayland',
        toolExists: (_) => true,
        startProcess: (list) async {
          args = list;
          return _FakeProc(stdoutText: '800x600+200+150\n', exitCode: 0);
        },
      );
      expect(picker.isAvailable, isTrue);
      final g = await picker.pick();
      expect(g!.width, 800);
      expect(g.x, 200);
      expect(g.y, 150);
      expect(args, ['slurp', '-f', '%wx%h+%x+%y']);
    });

    test('取消(退出码非 0)→ null', () async {
      final picker = ScreenRegionPicker(
        sessionType: 'wayland',
        toolExists: (_) => true,
        startProcess: (args) async => _FakeProc(stdoutText: '', exitCode: 1),
      );
      expect(await picker.pick(), isNull);
    });
  });

  group('CompositeRegionPicker', () {
    test('Wayland → 转发 slurp 实现', () async {
      final overlay = _FakeRegionPicker();
      final composite = CompositeRegionPicker(
        wayland: true,
        slurpPicker: ScreenRegionPicker(
          sessionType: 'wayland',
          toolExists: (_) => true,
          startProcess: (args) async =>
              _FakeProc(stdoutText: '800x600+200+150\n', exitCode: 0),
        ),
        overlayPicker: overlay,
      );
      expect(composite.isAvailable, isTrue);
      final g = await composite.pick();
      expect(g!.x, 200);
      expect(overlay.pickCount, 0, reason: 'Wayland 不触碰 overlay 实现');
    });

    test('非 Wayland(X11/Windows)→ 转发 overlay 实现', () async {
      final overlay = _FakeRegionPicker(
        available: true,
        geometry: const RegionGeometry(x: 10, y: 20, width: 640, height: 480),
      );
      final composite = CompositeRegionPicker(
        wayland: false,
        slurpPicker: ScreenRegionPicker(
          sessionType: 'x11',
          toolExists: (_) => true,
        ),
        overlayPicker: overlay,
      );
      expect(composite.isAvailable, isTrue);
      final g = await composite.pick();
      expect(g!.width, 640);
      expect(overlay.pickCount, 1);
    });

    test('overlay 不可用 → isAvailable false(UI 回退数字输入)', () {
      final composite = CompositeRegionPicker(
        wayland: false,
        slurpPicker: ScreenRegionPicker(
          sessionType: 'x11',
          toolExists: (_) => true,
        ),
        overlayPicker: _FakeRegionPicker(available: false),
      );
      expect(composite.isAvailable, isFalse);
    });
  });
}

/// 记录 pick 调用的 fake overlay 实现(接口契约验证)。
class _FakeRegionPicker implements RegionPicker {
  _FakeRegionPicker({this.available = true, this.geometry});

  final bool available;
  final RegionGeometry? geometry;
  int pickCount = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<RegionGeometry?> pick() async {
    pickCount++;
    return geometry;
  }
}

late List<String> args;

class _FakeProc implements Process {
  _FakeProc({required this.stdoutText, required int exitCode})
    : exitCodeValue = exitCode;

  final String stdoutText;
  final int exitCodeValue;

  @override
  Future<int> get exitCode async => exitCodeValue;

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(stdoutText));

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

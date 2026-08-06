import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/screen_record/application/record_environment_detector.dart';

/// 录屏环境探测纯函数(X11/Wayland/兜底全组合)。
void main() {
  test('wayland 会话 → pipewire', () {
    final env = detectRecordEnvironment(sessionType: 'wayland', display: ':1');
    expect(env.method, RecordCaptureMethod.pipewire);
    expect(env.display, isNull);
  });

  test('Wayland 大小写不敏感', () {
    final env = detectRecordEnvironment(sessionType: 'Wayland', display: null);
    expect(env.method, RecordCaptureMethod.pipewire);
  });

  test('x11 会话 → x11grab,透传 display', () {
    final env = detectRecordEnvironment(sessionType: 'x11', display: ':0');
    expect(env.method, RecordCaptureMethod.x11grab);
    expect(env.display, ':0');
  });

  test('无会话类型但有 DISPLAY → 兜底 x11grab(测试/CI 注入场景)', () {
    final env = detectRecordEnvironment(sessionType: null, display: ':1');
    expect(env.method, RecordCaptureMethod.x11grab);
    expect(env.display, ':1');
  });

  test('会话类型与 DISPLAY 皆缺 → none(不可用)', () {
    final env = detectRecordEnvironment(sessionType: null, display: null);
    expect(env.method, RecordCaptureMethod.none);
  });

  test('空串会话类型 + 空 DISPLAY → none', () {
    final env = detectRecordEnvironment(sessionType: '', display: '');
    expect(env.method, RecordCaptureMethod.none);
  });
}

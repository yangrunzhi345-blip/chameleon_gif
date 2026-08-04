import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/preview/infrastructure/media_kit_player_port.dart';
import 'package:media_kit/media_kit.dart';

/// P2 阶段门真实播放冒烟(需桌面环境 + media_kit 原生库):
///   flutter test -d linux integration_test/preview_smoke_test.dart
///
/// 覆盖:打开即播放标志、时长探测、连续切换 3 段样本 dispose 无泄漏
/// (docs/12-开发计划.md P2 阶段门)。
///
/// 注意:集成测试无渲染 surface 时 mpv 播放头不推进(time-pos 恒为 0),
/// 故 position 增长 / seek 精度断言不在此自动化,由 flutter run -d linux
/// 手动验证(见 docs/12 P2 阶段门)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  const kSamples = [
    '/tmp/gifforge_p1/sample_30fps.mp4',
    '/tmp/gifforge_p1/sample_1080p.mp4',
    '/tmp/gifforge_p1/sample_with_audio.mp4',
  ];

  test('打开即播放 → 时长探测 → pause → dispose(3 轮切换无泄漏)', () async {
    for (final path in kSamples) {
      final port = MediaKitPlayerPort();

      // 1. 打开(自动播放)
      await port.open(path);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(port.state.playing, isTrue, reason: '打开后应自动播放: $path');
      expect(port.state.duration, greaterThan(Duration.zero));

      // 2. 暂停
      port.pause();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(port.state.playing, isFalse, reason: '暂停后应停止播放: $path');

      // 3. dispose 无异常(泄漏回归)
      await port.dispose();
      // 幂等回归:二次 dispose 不抛(双路径释放防护,MediaKitPlayerPort._disposed)
      await port.dispose();
    }
  });
}

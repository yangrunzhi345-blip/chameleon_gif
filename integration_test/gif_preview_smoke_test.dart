import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/preview/infrastructure/media_kit_player_port.dart';
import 'package:media_kit/media_kit.dart';

/// 完成 GIF 预览门禁冒烟(验证 mpv 内置 GIF demuxer 可播放,任务 4 门禁):
///   flutter test -d linux integration_test/gif_preview_smoke_test.dart
///
/// 覆盖:打开 GIF 即自动播放(循环)、pause、dispose 幂等。
/// 夹具:test/fixtures/videos/clip_gif.gif(系统 ffmpeg 生成,2s 循环,
/// 已提交仓库)。
/// 注意:① 无渲染 surface 时播放头不推进(position 断言不在此自动化,
/// 与 preview_smoke_test 一致);② GIF 循环动画 duration 报告为 0,
/// 控制条已兜底(max:1),不做时长断言。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  const gifPath = 'test/fixtures/videos/clip_gif.gif';

  test('打开 GIF → 自动播放 → pause → dispose 幂等', () async {
    final port = MediaKitPlayerPort();

    // 1. 打开(自动播放,mpv GIF demuxer;时长可探测与否不强断言)
    await port.open(gifPath);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(port.state.playing, isTrue, reason: 'GIF 打开后应自动播放');

    // 2. 暂停
    port.pause();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(port.state.playing, isFalse, reason: '暂停后应停止播放');

    // 3. dispose 无异常(泄漏回归)+ 幂等
    await port.dispose();
    await port.dispose();
  });
}

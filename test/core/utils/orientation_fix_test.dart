import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/utils/orientation_fix.dart';

/// [buildOrientationFixCommand] 组合矩阵单测(横竖屏拍摄 × rotation 元数据)。
void main() {
  const input = '/tmp/src.mp4';
  const output = '/tmp/src.mp4.rotated.mp4';

  List<String> call({int? rotation, required bool portrait}) =>
      buildOrientationFixCommand(
        rotation: rotation,
        devicePortrait: portrait,
        input: input,
        output: output,
      )!;

  group('竖屏拍摄(目标竖屏)', () {
    test('rotation -90(标准竖拍元数据)→ autorotate 重编码(无 -vf)', () {
      final cmd = call(rotation: -90, portrait: true);
      expect(cmd, isNot(contains('-noautorotate')));
      expect(cmd, contains('-i'));
      expect(cmd, contains('h264_mediacodec'));
      expect(cmd.last, output);
    });

    test('rotation 0/缺失(部分设备不写元数据)→ transpose=1 强制转竖', () {
      final cmd = call(rotation: 0, portrait: true);
      expect(cmd, contains('-noautorotate'));
      expect(cmd, contains('-vf'));
      expect(cmd, contains('transpose=1'));
    });

    test('rotation 缺失(null)→ 同 0,强制转竖', () {
      final cmd = call(rotation: null, portrait: true);
      expect(cmd, contains('transpose=1'));
    });

    test('rotation 180(倒着竖拍)→ autorotate 自动旋转', () {
      final cmd = call(rotation: 180, portrait: true);
      expect(cmd, isNot(contains('-noautorotate')));
    });
  });

  group('横屏拍摄(目标横屏)', () {
    test('rotation 0(标准横拍)→ 不转码(null)', () {
      expect(
        buildOrientationFixCommand(
          rotation: 0,
          devicePortrait: false,
          input: input,
          output: output,
        ),
        isNull,
      );
    });

    test('rotation 缺失 → 不转码', () {
      expect(
        buildOrientationFixCommand(
          rotation: null,
          devicePortrait: false,
          input: input,
          output: output,
        ),
        isNull,
      );
    });

    test('rotation -90(横拍误写元数据)→ transpose=2 转回横屏', () {
      final cmd = call(rotation: -90, portrait: false);
      expect(cmd, contains('-noautorotate'));
      expect(cmd, contains('transpose=2'));
    });

    test('rotation 90 → transpose=1 转回横屏', () {
      final cmd = call(rotation: 90, portrait: false);
      expect(cmd, contains('transpose=1'));
    });

    test('rotation 180 → 不转码(横屏保持,倒置可接受)', () {
      expect(
        buildOrientationFixCommand(
          rotation: 180,
          devicePortrait: false,
          input: input,
          output: output,
        ),
        isNull,
      );
    });
  });

  test('命令含 -y / h264_mediacodec / -an(FFmpegKit 契约)', () {
    final cmd = call(rotation: 90, portrait: true);
    expect(cmd.first, '-y');
    expect(cmd, contains('h264_mediacodec'));
    expect(cmd, contains('-an'));
    expect(cmd.last, output);
  });
}

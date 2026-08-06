import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/utils/video_rotation.dart';
import 'package:chameleon_gif/shared/platform/ffprobe_executor.dart';

/// [parseRotationDegrees] 纯函数测试:带 rotation/无/缺失/异常结构。
void main() {
  FfprobeResult resultWith(Map<dynamic, dynamic>? probeJson) =>
      FfprobeResult(exitCode: 0, stderr: '', probeJson: probeJson);

  test('带 rotation(-90,竖屏拍摄标准姿势)→ -90', () {
    final r = resultWith({
      'streams': [
        {
          'width': 1280,
          'height': 720,
          'side_data_list': [
            {'rotation': -90},
          ],
        },
      ],
    });
    expect(parseRotationDegrees(r), -90);
  });

  test('无 side_data_list(横屏/竖屏流)→ null(无需旋转)', () {
    final r = resultWith({
      'streams': [
        {'width': 1920, 'height': 1080},
      ],
    });
    expect(parseRotationDegrees(r), isNull);
  });

  test('rotation 为 0 → 0(无需旋转)', () {
    final r = resultWith({
      'streams': [
        {
          'width': 720,
          'height': 1280,
          'side_data_list': [
            {'rotation': 0},
          ],
        },
      ],
    });
    expect(parseRotationDegrees(r), 0);
  });

  test('probeJson 缺失(异常/桌面失败)→ null', () {
    expect(parseRotationDegrees(resultWith(null)), isNull);
  });

  test('streams 结构异常(非 List / 空)→ null', () {
    expect(parseRotationDegrees(resultWith({'streams': 'oops'})), isNull);
    expect(parseRotationDegrees(resultWith({'streams': []})), isNull);
  });

  test('rotation 非数字 → null(容错)', () {
    final r = resultWith({
      'streams': [
        {
          'side_data_list': [
            {'rotation': 'unknown'},
          ],
        },
      ],
    });
    expect(parseRotationDegrees(r), isNull);
  });
}

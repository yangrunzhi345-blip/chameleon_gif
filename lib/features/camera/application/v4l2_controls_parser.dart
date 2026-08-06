/// v4l2-ctl 控制项输出解析(纯函数,可单测;本机真实输出固化为夹具)。
///
/// 支持 `v4l2-ctl -l` 与 `v4l2-ctl -L`(后者含 menu 完整选项行);
/// 仅 int/bool/menu 三型进入结果(rect/bitmask 等不支持类型跳过),
/// `flags=inactive` 标记当前不活跃(自动模式联动,如自动白平衡开启时
/// 色温项),设置面板据此置灰。
library;

import '../../../domain/value_objects/camera_types.dart';

/// 解析 `v4l2-ctl -L` 输出 → 可调控制项列表。
///
/// 行形态(实测):
/// ```
///                      brightness 0x00980900 (int)    : min=-64 max=64 ...
///         white_balance_automatic 0x0098090c (bool)   : default=1 value=1
///            power_line_frequency 0x00980918 (menu)   : min=0 max=2 ... (60 Hz)
/// 				0: Disabled
/// 				1: 50 Hz
/// 				2: 60 Hz
/// ```
/// menu 选项行(制表符缩进 `N: label`)归属其前一个 menu 控制项。
List<CameraControlCapability> parseV4l2Controls(String output) {
  final controls = <CameraControlCapability>[];
  final controlPattern = RegExp(
    r'^\s+(\S+)\s+0x[0-9a-f]+\s+\((\w+)\)\s*:\s*(.*)$',
  );
  final optionPattern = RegExp(r'^\s*(\d+):\s+(.+)$');

  for (final rawLine in output.split('\n')) {
    final controlMatch = controlPattern.firstMatch(rawLine);
    if (controlMatch != null) {
      final id = controlMatch.group(1)!;
      final type = controlMatch.group(2)!;
      if (type != 'int' && type != 'bool' && type != 'menu') continue;
      final rest = controlMatch.group(3)!;
      int? intOf(String key) {
        final m = RegExp('\\b$key=(-?\\d+)').firstMatch(rest);
        return m == null ? null : int.parse(m.group(1)!);
      }
      final flagsMatch = RegExp(r'flags=([\w,\- ]+)$').firstMatch(rest);
      final flags = flagsMatch?.group(1) ?? '';
      final currentValue = intOf('value');
      final menuLabel = RegExp('value=-?\\d+ \\(([^)]+)\\)').firstMatch(rest);
      final choices = <int, String>{};
      if (menuLabel != null && currentValue != null) {
        choices[currentValue] = menuLabel.group(1)!;
      }
      controls.add(
        CameraControlCapability(
          id: id,
          kind: switch (type) {
            'int' => CameraControlKind.int,
            'bool' => CameraControlKind.bool,
            _ => CameraControlKind.menu,
          },
          min: intOf('min'),
          max: intOf('max'),
          step: intOf('step'),
          defaultValue: intOf('default'),
          value: currentValue,
          active: !flags.contains('inactive'),
          choices: choices.isEmpty ? null : choices,
        ),
      );
      continue;
    }
    // menu 选项行:归属最后一个 menu 控制项
    final optionMatch = optionPattern.firstMatch(rawLine);
    if (optionMatch != null && controls.isNotEmpty) {
      final last = controls.last;
      if (last.kind == CameraControlKind.menu) {
        final id = int.parse(optionMatch.group(1)!);
        last.choices![id] = optionMatch.group(2)!.trim();
      }
    }
  }
  return controls;
}

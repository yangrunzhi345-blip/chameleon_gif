import '../../../domain/value_objects/task_progress.dart';

/// `-progress pipe:1` 输出行解析器(纯 Dart,可单测,docs/08 §8.3.3)。
///
/// 逐行输入 `key=value`,产出 [TaskProgress]:
/// - `out_time_us` → percent = 输出时间戳 / 裁剪时长(分母由调用方注入,
///   即 CommandBuilder.progressDenominator),钳制 [0,1];
/// - `total_size` → speedKbPerSec(差分近似);
/// - `speed`(如 `2.5x`/`0x`/`N/A`)→ 实时倍速,剩余时长优先按速度估算;
/// - speed 恒 0 时降级:按已耗时线性预估 remaining(percent>0 时);
/// - 非法行返回 null 丢弃不中断(R-09)。
class ProgressParser {
  ProgressParser({required this.taskId, required Duration denominator})
    : _denominatorUs = denominator.inMicroseconds;

  final int taskId;

  /// 裁剪总时长(微秒);非正时进度恒 100%(除零防护)。
  final int _denominatorUs;

  Duration? _lastElapsed;
  int? _lastTotalSize;
  double? _speed;

  /// 解析单行;产出进度时返回非空,非法行返回 null。
  TaskProgress? next(String line) {
    final eq = line.indexOf('=');
    if (eq <= 0) return null;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    switch (key) {
      case 'out_time_us':
        final us = int.tryParse(value);
        if (us == null) return null;
        _lastElapsed = Duration(microseconds: us);
      case 'total_size':
        _lastTotalSize = int.tryParse(value);
        return null; // 尺寸行单独不产出(等待 out_time 对齐)
      case 'speed':
        _speed = _parseSpeed(value);
        return null;
      default:
        return null; // 其余键(progress/frame/bitrate 等)暂不驱动进度
    }
    return _build();
  }

  /// speed 值形如 `2.5x`;`0x`/`N/A`/非法 → null(触发线性预估降级)。
  double? _parseSpeed(String value) {
    final match = RegExp(r'^(\d+(?:\.\d+)?)x?$').firstMatch(value.trim());
    if (match == null) return null;
    final v = double.parse(match.group(1)!);
    return v > 0 ? v : null;
  }

  TaskProgress _build() {
    final elapsedUs = _lastElapsed?.inMicroseconds ?? 0;
    final percent = _denominatorUs <= 0
        ? 1.0
        : (elapsedUs / _denominatorUs).clamp(0.0, 1.0);

    // 写入速度:total_size / 已耗时(近似,字节→KB)
    var speedKbPerSec = 0;
    final elapsedSec = elapsedUs / 1e6;
    if (_lastTotalSize != null && elapsedSec > 0) {
      speedKbPerSec = ((_lastTotalSize! / elapsedSec) / 1024).round();
    }

    // 剩余时长:有速度用速度,否则按已耗时线性预估(percent>0 才可估)。
    Duration? remaining;
    final remainUs = _denominatorUs - elapsedUs;
    if (remainUs > 0) {
      if (_speed != null) {
        remaining = Duration(microseconds: (remainUs / _speed!).round());
      } else if (percent > 0) {
        remaining = Duration(
          microseconds: (elapsedUs * (1 - percent) / percent).round(),
        );
      }
    }

    return TaskProgress(
      taskId: taskId,
      percent: percent,
      elapsed: Duration(microseconds: elapsedUs),
      remaining: remaining,
      speedKbPerSec: speedKbPerSec,
    );
  }

  /// 当前累计耗时(测试/调试用)。
  Duration? get lastElapsed => _lastElapsed;
}

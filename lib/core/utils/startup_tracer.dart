import 'dart:io';

import '../logger/app_logger.dart';

/// 启动分段计时器(P7 基线采集;默认关闭,零开销)。
///
/// 激活方式:`GIFFORGE_STARTUP_PROFILE=1 flutter run -d linux`(环境变量
/// 门控,产物不带入用户路径)。main 入口起按步骤 [mark],首帧回调后
/// [dump] 一次性输出全部分段耗时,供 P7 启动优化决策与基线记录。
class StartupTracer {
  StartupTracer(this._logger);

  /// 是否激活(仅显式设置环境变量时记录,默认零开销)。
  static bool get isEnabled =>
      Platform.environment['GIFFORGE_STARTUP_PROFILE'] == '1';

  final AppLogger _logger;
  final Stopwatch _watch = Stopwatch();
  final Map<String, Duration> _marks = {};

  /// 记录分段耗时(相对入口第一次调用)。
  void mark(String step) {
    if (!isEnabled) return;
    if (!_watch.isRunning) {
      _watch.start();
    }
    _marks[step] = _watch.elapsed;
  }

  /// 输出全部分段(供启动耗时定位与 docs/17 基线记录)。
  void dump() {
    if (!isEnabled || _marks.isEmpty) {
      return;
    }
    final lines = _marks.entries
        .map((e) => '  ${e.key}: ${e.value.inMilliseconds} ms')
        .join('\n');
    _logger.i('启动分段耗时(GIFFORGE_STARTUP_PROFILE):\n$lines');
  }
}

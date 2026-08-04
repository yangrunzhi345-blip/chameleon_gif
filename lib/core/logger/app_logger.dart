import 'package:logger/logger.dart';

/// 应用统一日志入口(console 通道;文件落盘与轮转由后续阶段补,
/// 见 docs/11-开发规范.md 日志章节)。
///
/// 使用:final log = ref.read(appLoggerProvider);
class AppLogger {
  AppLogger({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  void d(String msg, {Object? error, StackTrace? stackTrace}) =>
      _logger.d(msg, error: error, stackTrace: stackTrace);

  void i(String msg, {Object? error, StackTrace? stackTrace}) =>
      _logger.i(msg, error: error, stackTrace: stackTrace);

  void w(String msg, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(msg, error: error, stackTrace: stackTrace);

  void e(String msg, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(msg, error: error, stackTrace: stackTrace);

  void f(String msg, {Object? error, StackTrace? stackTrace}) =>
      _logger.f(msg, error: error, stackTrace: stackTrace);
}

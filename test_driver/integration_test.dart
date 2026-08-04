import 'package:integration_test/integration_test_driver.dart';

/// integration_test 的标准 driver(性能基准用 profile 模式运行):
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/perf_benchmark_test.dart -d linux --profile
Future<void> main() => integrationDriver();

/// 覆盖率门禁汇总(docs/17 P8 三项硬指标):
///
/// ```bash
/// bash tool/ascii_sync.sh && cd /tmp/gifforge_copy && flutter pub get \
///   && flutter test --coverage \
///   && dart run tool/coverage_summary.dart coverage/lcov.info
/// ```
///
/// 解析 lcov.info(SF 源文件 / DA 行计数),按目录前缀聚合三项目标
/// (converter ≥85% / task_queue ≥80% / domain ≥90%);任一未达标 exit 1,
/// 供 CI 门禁使用。生成文件(.freezed/.g.dart)计入行覆盖,不排除。
library;

// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final lcovPath = args.isNotEmpty ? args.first : 'coverage/lcov.info';
  final file = File(lcovPath);
  if (!file.existsSync()) {
    stderr.writeln('未找到 lcov 文件: $lcovPath(先跑 flutter test --coverage)');
    exit(2);
  }

  const targets = <String, double>{
    'lib/features/converter': 85.0,
    'lib/features/task_queue': 80.0,
    'lib/domain': 90.0,
  };
  final stats = <String, ({int hit, int total})>{
    for (final t in targets.keys) t: (hit: 0, total: 0),
  };

  String? current;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll('\\', '/');
      if (!current.startsWith('lib/')) {
        current = null; // 只统计 lib 源码
      }
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      final count = parts.length >= 2 ? int.tryParse(parts[1]) : null;
      if (count == null) {
        continue;
      }
      for (final dir in stats.keys) {
        if (current.startsWith('$dir/')) {
          final s = stats[dir]!;
          stats[dir] = (hit: s.hit + (count > 0 ? 1 : 0), total: s.total + 1);
          break;
        }
      }
    }
  }

  var failed = false;
  print('覆盖率门禁汇总($lcovPath):');
  for (final entry in targets.entries) {
    final s = stats[entry.key]!;
    final pct = s.total == 0 ? 0.0 : 100.0 * s.hit / s.total;
    final ok = pct >= entry.value;
    print(
      '  ${entry.key}: ${s.hit}/${s.total} = ${pct.toStringAsFixed(1)}% '
      '(门槛 ${entry.value}%) ${ok ? '✅' : '❌'}',
    );
    if (!ok) {
      failed = true;
    }
  }
  if (failed) {
    print('❌ 覆盖率未达标,请补测试(见 docs/17 合并 WP2)');
    exit(1);
  }
  print('✅ 覆盖率三项达标');
}

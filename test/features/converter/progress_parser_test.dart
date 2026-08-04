import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/converter/application/progress_parser.dart';

/// [ProgressParser] 单测(docs/14-测试计划.md §14.2,进度解析契约)。
void main() {
  ProgressParser parser({Duration denominator = const Duration(seconds: 10)}) {
    return ProgressParser(taskId: 42, denominator: denominator);
  }

  group('out_time_us → percent', () {
    test('0/10s → 0%;5s/10s → 50%;10s/10s → 100%', () {
      final p = parser();
      expect(p.next('out_time_us=0')!.percent, 0.0);
      expect(p.next('out_time_us=5000000')!.percent, 0.5);
      expect(p.next('out_time_us=10000000')!.percent, 1.0);
    });

    test('分母 = 裁剪时长(end-start),与 CommandBuilder 分母一致', () {
      final p = parser(denominator: const Duration(seconds: 20));
      expect(p.next('out_time_us=10000000')!.percent, 0.5);
    });

    test('out_time 越过 -to 时钳制到 1.0', () {
      final p = parser();
      final progress = p.next('out_time_us=15000000');
      expect(progress!.percent, 1.0);
    });

    test('非数字值(N/A)丢弃不产出', () {
      final p = parser();
      expect(p.next('out_time_us=N/A'), isNull);
      expect(p.next('out_time_us=abc'), isNull);
    });

    test('elapsed 记录输出时间戳', () {
      final p = parser();
      expect(
        p.next('out_time_us=1234567')!.elapsed,
        const Duration(microseconds: 1234567),
      );
    });
  });

  group('total_size → speedKbPerSec', () {
    test('total_size 单独行不产出进度(等 out_time 对齐)', () {
      final p = parser();
      expect(p.next('total_size=10240'), isNull);
    });

    test('尺寸/耗时 → KB/s', () {
      final p = parser();
      p.next('out_time_us=1000000'); // 1s
      final progress = p.next('total_size=1024000'); // 1000 KB
      expect(progress, isNull, reason: 'total_size 行本身不产出');
      // 下一次 out_time 时带上速度
      final next = p.next('out_time_us=2000000');
      expect(next!.speedKbPerSec, greaterThan(0));
      // 1024000 B / 2s / 1024 = 500 KB/s
      expect(next.speedKbPerSec, 500);
    });

    test('elapsed 为 0 时速度为 0(除零防护)', () {
      final p = parser();
      final progress = p.next('out_time_us=0')!;
      expect(progress.speedKbPerSec, 0);
    });
  });

  group('remaining 预估', () {
    test('有 speed 时按剩余时长/速度估算', () {
      final p = parser();
      p.next('out_time_us=5000000'); // 50%,剩 5s
      p.next('speed=2.5x');
      final progress = p.next('out_time_us=5000001');
      expect(progress!.remaining, const Duration(seconds: 2));
    });

    test('speed=0x / N/A 触发线性预估', () {
      final p = parser();
      p.next('out_time_us=5000000'); // 50%,elapsed 5s → remaining 5s
      expect(p.next('speed=0x'), isNull);
      final progress = p.next('out_time_us=5000001');
      // 浮点除法有微秒级误差,按毫秒容差断言
      expect(progress!.remaining!.inMilliseconds, closeTo(5000, 100));
    });

    test('percent=0 时无法线性预估,remaining 为 null', () {
      final p = parser();
      final progress = p.next('out_time_us=0')!;
      expect(progress.remaining, isNull);
    });

    test('进度 100% 后 remaining 为 null', () {
      final p = parser();
      final progress = p.next('out_time_us=10000000')!;
      expect(progress.remaining, isNull);
    });
  });

  group('非法行与边界(R-09)', () {
    test('无 = 的行返回 null 不抛', () {
      final p = parser();
      expect(p.next('frame=1'), isNull);
      expect(p.next(''), isNull);
      expect(p.next('progress=continue'), isNull);
      expect(p.next('这是一行乱码'), isNull);
    });

    test('denominator 非正时恒 100%(除零防护)', () {
      final p = parser(denominator: Duration.zero);
      expect(p.next('out_time_us=0')!.percent, 1.0);
    });
  });

  test('taskId 透传', () {
    final p = parser();
    final progress = p.next('out_time_us=1000000')!;
    expect(progress, isA<TaskProgress>());
    expect(progress.taskId, 42);
  });
}

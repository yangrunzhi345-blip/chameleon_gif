import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/converter/application/log_parser.dart';

/// [LogParser] 分级测试(docs/08 §8.3.4)。
void main() {
  const parser = LogParser();

  (List<String>, List<String>, List<String>) classify(String line) {
    final errors = <String>[], warns = <String>[], infos = <String>[];
    parser.parse(
      line,
      onError: errors.add,
      onWarn: warns.add,
      onInfo: infos.add,
    );
    return (errors, warns, infos);
  }

  test('[error] 行 → 错误级', () {
    final (errors, warns, infos) = classify('[error] Invalid data found');
    expect(errors, ['[error] Invalid data found']);
    expect(warns, isEmpty);
    expect(infos, isEmpty);
  });

  test('Error / Invalid 关键词 → 错误级', () {
    expect(classify('Error: no such file').$1, hasLength(1));
    expect(classify('Invalid argument').$1, hasLength(1));
  });

  test('[warning] 行 → 警告级', () {
    final (errors, warns, infos) = classify('[warning] deprecated filter');
    expect(warns, ['[warning] deprecated filter']);
    expect(errors, isEmpty);
  });

  test('普通行 → 信息级', () {
    final (errors, warns, infos) = classify('ffmpeg version 6.1.1');
    expect(infos, ['ffmpeg version 6.1.1']);
    expect(errors, isEmpty);
    expect(warns, isEmpty);
  });

  test('超长行截断', () {
    final long = 'x' * 1000;
    final (errors, _, _) = classify('Error: $long');
    expect(
      errors.single.length,
      lessThanOrEqualTo(LogParser.kMaxLineLength + 1),
    );
    expect(errors.single.endsWith('…'), isTrue);
  });
}

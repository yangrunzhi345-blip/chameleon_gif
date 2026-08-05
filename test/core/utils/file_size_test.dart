import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/utils/file_size.dart';

/// [formatFileSize] 边界测试(导出完成弹窗/队列页展示)。
void main() {
  test('B 段(<1KB)', () {
    expect(formatFileSize(0), '0 B');
    expect(formatFileSize(1), '1 B');
    expect(formatFileSize(1023), '1023 B');
  });

  test('KB 段(1KB–1MB,一位小数)', () {
    expect(formatFileSize(1024), '1.0 KB');
    expect(formatFileSize(1536), '1.5 KB');
    expect(formatFileSize(1024 * 1024 - 1), '1024.0 KB');
  });

  test('MB 段(≥1MB,一位小数)', () {
    expect(formatFileSize(1024 * 1024), '1.0 MB');
    expect(formatFileSize((1.5 * 1024 * 1024).round()), '1.5 MB');
  });

  test('负值(异常输入防御:仍按 <1KB 处理)', () {
    expect(formatFileSize(-1), '-1 B');
  });
}

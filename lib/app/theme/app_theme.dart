import 'package:flutter/material.dart';

/// Material 3 主题(M3 全面启用,见 docs/10-UI设计.md §10.4)。
class AppTheme {
  const AppTheme._();

  /// 品牌色种子(深浅两套由同一 seed 派生,保证一致性)
  static const seedColor = Color(0xFF6750A4);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // 桌面三端一致的滚动条与控件基础样式(后续阶段按需细化)
    );
  }
}

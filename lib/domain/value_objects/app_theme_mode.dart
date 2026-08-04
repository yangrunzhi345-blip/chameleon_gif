/// 应用主题三态(领域自有枚举,domain 零 Flutter 依赖;
/// 映射为 Flutter `ThemeMode` 收敛于 UI 层,docs/04 §4.2 Domain 禁区)。
enum AppThemeMode { light, dark, system }

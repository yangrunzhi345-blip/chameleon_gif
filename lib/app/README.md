# lib/app — 应用根

职责(Presentation 层入口):

- `main.dart` 引用入口(`GifForgeApp`),组装 `ProviderScope` 与初始化回调
- 路由表(`GoRouter` 配置,见 `docs/09-状态管理.md` 与 `docs/10-UI设计.md`)
- 主题(`ThemeMode` 三态 + Material 3 `ColorScheme.fromSeed`)
- 多语言(Locale 三态,预留 l10n 目录)
- 全局 Provider(ProviderScope overrides 在此注入)

禁止:业务逻辑、FFmpeg/Isar 直接调用。

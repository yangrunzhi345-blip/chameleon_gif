# lib/shared — 跨功能复用

- `widgets/` — 通用 UI 组件(进度条、按钮、空状态、错误视图)
- `models/` — 跨模块共享的数据模型(Freezed + json_serializable)
- `repositories/` — 仓储实现(Isar、SharedPreferences 等,Infrastructure 层)
- `platform/` — PlatformAdapter 与平台差异封装(见 `docs/08-FFmpeg设计.md`)
- `services/` — 应用级服务(日志、配置、导航、通知)

禁止:shared 不得依赖 features 任何内容。

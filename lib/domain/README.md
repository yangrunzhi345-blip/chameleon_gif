# lib/domain — 领域层(最内层)

零依赖层:不 import Flutter、不 import 任何基础设施包。仅纯 Dart。

- `entities/` — 领域实体(VideoInfo、ExportTask、ExportHistory、ExportPreset,见 `docs/07-数据库设计.md`)
- `value_objects/` — 值对象(GifSetting、TaskState、TaskProgress、DurationRange 等,Freezed 不可变)
- `repository_interfaces/` — 仓储接口(HistoryRepository、TaskRepository、SettingsRepository)

禁止:依赖 `core/`、`shared/`、`features/`、任何 Flutter 库。依赖方向只能被上层指向本层。

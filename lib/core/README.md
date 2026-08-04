# lib/core — 横切关注点

不隶属于任何功能模块的公共基础:

- `constants/` — 常量、枚举、默认转换参数(k 前缀)
- `exceptions/` — 自定义异常层级(领域异常在 `domain/`,基础设施异常在此)
- `logger/` — Logger 初始化与封装(见 `docs/11-开发规范.md` 日志章节)
- `utils/` — 通用工具(时间格式化、文件大小、FFmpeg 时长解析等,纯函数)

禁止:core 不得 import `domain/` 与 `features/` 之外的业务代码;不得依赖第三方重包。

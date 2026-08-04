# lib/features — 功能模块

各功能模块目录(职责与边界见 `docs/06-模块设计.md`):

| 目录 | 模块 | 职责 |
|------|------|------|
| `import/` | Import | 文件选择、视频解析入口 |
| `preview/` | Preview | MediaKit 播放器、播放/暂停/seek |
| `timeline/` | Timeline | 时间轴、起止时间选择 |
| `export/` | Export | 参数面板、导出流程编排(Application 用例) |
| `history/` | History | 转换记录列表与详情 |
| `settings/` | Settings | 默认参数与偏好设置 |
| `task_queue/` | TaskQueue | 任务队列、并发调度、状态机 |
| `converter/` | FFmpeg | FFmpegEngine 接口与平台实现(命令构造/进度/取消) |

**模块边界**:features 之间互不依赖,跨模块协作一律经 Application 用例(Provider 注入)协调。

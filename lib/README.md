# lib/ — GifForge 源码目录

五层架构的 Flutter 落地,详细设计见 `docs/04-系统架构.md` 与 `docs/05-目录结构.md`。

```
lib/
├── main.dart      # 入口:初始化(Isar、Logger、ProviderScope、MediaKit)
├── app/           # 根:MaterialApp、路由表、主题、依赖注入
├── core/          # 横切:常量、异常、日志、工具
├── domain/        # 领域层:实体、值对象、仓储接口(最内层,零依赖)
├── features/      # 功能模块(import/preview/timeline/export/history/settings/task_queue/converter)
└── shared/        # 跨功能复用:widgets/models/repositories/platform/services
```

**禁止依赖规则**(详见 docs/05):features 之间互不依赖;domain 不得依赖任何层;core 不得反向依赖 domain 与 features;shared 不得依赖 features。

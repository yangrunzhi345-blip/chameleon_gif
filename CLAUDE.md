# CLAUDE.md

## 一、项目身份

我是一名 Flutter 开发者,正在开发 **Chameleon Gif**:一款 **MP4 转 GIF** 的跨平台工具。**首发平台:Linux(主要开发平台)、Windows、Android**;macOS / Web / iOS 为预留平台(V3 及以后)。选择 Flutter 的核心原因是**全平台一套代码**;架构要求:首发三平台体验一致,预留平台不破坏现有接口(详见 docs/01-项目介绍.md 与 docs/16-V2.0扩展规划.md)。

**完整技术设计说明书在 `docs/` 目录(17 篇),本文件与 docs/03-技术选型.md 版本锁定表同步维护,冲突时以 docs/ 为准。**

**核心功能:**

1. 选择 MP4 视频文件
2. 配置转换参数:输出帧率、宽高/缩放、起止时间裁剪、质量
3. 调用 FFmpeg 执行 MP4 → GIF 转换,实时展示进度
4. 转换记录持久化(历史列表、重转、删除)
5. 保存/预览输出 GIF

## 二、Git 管理规范(强制性)

> 铁律:**任务开始前先 Git,任务完成后必 Git。**

### 2.1 任务开始前

```bash
git status          # 确认工作区干净,无未提交残留
git pull            # 同步远程最新代码
git switch -c feat/<分支名>   # 从最新 main 拉出功能分支
```

- 禁止在未同步的旧代码基础上直接开工。
- 开工前记录本次任务目标,对应到分支与提交主题。

### 2.2 任务完成后

```bash
dart format .            # 先格式化
flutter analyze          # 静态分析零告警
flutter test             # 测试通过
git add -A
git commit -m "<规范提交信息>"
git push
```

- 一个小功能或修复 = 一个提交,禁止"攒一堆再提交"。
- 提交信息规范:`type(scope): 中文描述`,type 取值:
  - `feat` 新功能 / `fix` 修复 / `refactor` 重构 / `docs` 文档 / `chore` 构建与依赖 / `test` 测试 / `perf` 性能
  - 示例:`feat(convert): 支持调色板优化转换模式`

## 三、技术栈与版本

### 3.1 版本锁定(以 pubspec.yaml 为准,升级需走 chore 提交)

| 类别 | 依赖 | 版本 | 用途 |
|------|------|------|------|
| SDK | Flutter | `>=3.38.0` | 框架 |
| SDK | Dart | `>=3.10.0` | 语言 |
| 状态管理 | `flutter_riverpod` | `^3.3.1` | 全局状态管理 |
| 状态管理 | `riverpod_annotation` / `riverpod_generator` | `4.0.2` / `4.0.3`(精确) | Riverpod 代码生成 |
| 路由 | `go_router` | `^17.3.0` | 声明式路由 |
| 模型 | `freezed` + `freezed_annotation` | `3.2.5` / `^3.1.0` | 不可变数据模型 |
| 序列化 | `json_serializable` + `json_annotation` | `6.13.0` / `^4.11.0` | JSON 编解码 |
| 数据库 | `isar_community` + `isar_community_flutter_libs` + `isar_community_generator` | `^3.3.2` | 转换记录持久化 |
| 轻量存储 | `shared_preferences` | `^2.5.5` | 用户偏好(默认参数等) |
| 日志 | `logger` | `^2.7.0` | 统一日志 |
| 视频解码 | `media_kit` | `^1.2.6` | 视频播放(预览) |
| 视频渲染 | `media_kit_video` | `^2.0.1` | 播放器控件 |
| 原生库 | `media_kit_libs_video` | `^1.0.7` | 内置 FFmpeg 原生库(播放用) |
| **转码引擎** | `ffmpeg_kit_flutter_minimal` | `^6.0.8` | FFmpeg CLI 封装(**GIF 转换核心**) |
| 文件选择 | `file_picker` | `^11.0.3` | 选择 MP4 源文件 |
| 文件选择 | `file_selector` | `^1.1.0` | 官方方案,保存 GIF 对话框 |
| 代码生成 | `build_runner` | `2.15.1`(精确,见注) | 运行 freezed/isar/riverpod 生成器 |
| 分析 | `flutter_lints` | `^6.0.0` | 官方 lint(riverpod_lint 暂缓引入) |
| 转码引擎(iOS 预留) | `ffmpeg_kit_flutter` | `6.0.3`(固定,已停维护) | iOS 端 FFmpeg(预留评估) |
| 转码引擎(Web 预留) | `ffmpeg.wasm` | 以 pub.dev 最新为准 | Web 端 WASM 转码(预留) |

> **版本锁定说明**:代码生成器处于 analyzer 生态迁移期(analyzer 9→13),经交集验证的精确组合为 `freezed 3.2.5` + `json_serializable 6.13.0` + `isar_community_generator ^3.3.2` + `riverpod_generator 4.0.3` + `build_runner 2.15.1`(analyzer >=9 <11,source_gen >=4 <5),**禁止单独升级其中任一**(会破坏组合),整体升级需重新求解。

### 3.2 技术选型说明

- **转码引擎用 `ffmpeg_kit_flutter_minimal ^6.0.8`**(ffmpeg_kit_flutter 的活跃维护 fork,兼容新版 Flutter):`media_kit_ffmpeg` 包在 pub.dev 上不存在(media_kit 生态无 FFmpeg CLI 封装);原版 `ffmpeg_kit_flutter` 已于 2025 年停止维护,不直接选用。
- **FFmpeg 分平台接入**(详见 docs/08-FFmpeg设计.md;**已实证**:`ffmpeg_kit_flutter_minimal` 6.0.8 无 Linux/Windows 平台实现,仅 Android/iOS/macOS):
  - **桌面(Linux / Windows)**:经 `dart:io Process` 调**系统 ffmpeg/ffprobe 二进制**(P1 已实测解析链路 9/9);缺二进制抛 `FFmpegMissingException`,P9 打包补分发决策
  - **Android**:`ffmpeg_kit_flutter_minimal`(内置 FFmpeg+FFprobe 原生库,随包分发;本轮未验证,P8 三平台清单确认)
  - **预留平台**:macOS(同方案,补签名公证)、Web(WASM)、iOS(ffmpeg_kit_flutter 原版评审后引入)——均为预留,不进入 MVP 实现
  - 所有转码/探测实现收敛到统一抽象 `FfprobeExecutor` / `FFmpegEngine`,按平台注入具体实现,业务层对平台差异无感知
- **数据库用 `isar_community` 系列(^3.3.2)替代官方 `isar`(3.1.0)**:官方生成器依赖旧 source_gen,与现代代码生成器组合冲突;community fork API 兼容(import `package:isar_community/isar.dart`),为 docs/13-风险分析.md R-04 预案的实际落地。
- **Isar**:官方稳定版为 `3.1.0`(4.x 仍为 dev 版,**禁止在生产环境使用 4.0-dev 或社区 fork**,除非评审后明确切换)。
- 全部生成式代码(freezed / json / isar / riverpod)只允许通过 build_runner 生成,禁止手写改生成文件。

## 四、项目结构

```
lib/
├── main.dart                  # 入口:初始化(Isar、Logger、ProviderScope 注入组合装配)
├── app/                       # 组合根
│   ├── app.dart               # MaterialApp + GoRouter(主题枚举 → ThemeMode 映射)
│   ├── router.dart            # 路由表定义
│   ├── application/           # providers.dart(纯应用态)、theme_controller.dart
│   ├── presentation/          # home_page.dart、preview_screen.dart(跨模块 UI 组合壳)
│   └── theme/                 # app_theme.dart
├── core/
│   ├── logger/                # AppLogger 初始化与封装
│   └── utils/                 # 通用工具(formatFfmpegTime/formatHumanDuration/formatFileSize/throttleStream)
├── domain/                    # 零 Flutter 依赖(纯 Dart)
│   ├── entities/              # video_info、export_task、export_history、export_preset
│   ├── value_objects/         # gif_setting、task_state、task_progress、app_theme_mode
│   ├── exceptions/            # 领域异常层级(FilePick/Conversion 两族)
│   └── repository_interfaces/ # 端口(parse_video/player/task/history/settings/ffmpeg_engine/ffmpeg_service)
├── features/                  # 模块内部:application(纯 Dart)→ infrastructure → presentation
│   ├── converter/             # 命令构造/进度解析/错误映射(application)+ ffprobe 端口(infrastructure)
│   ├── import/                # 文件选择 + 导入用例
│   ├── preview/               # 视频预览(播放器端口/控制器/面板/控制条)
│   ├── task_queue/            # 任务调度状态机(application)
│   ├── export/                # 导出会话控制器 + 参数面板/进度/完成弹窗
│   └── history/               # 历史列表/详情/重转(P5;缩略图经 FFmpegEngine 端口)
└── shared/                    # 被所有层依赖,禁止反向依赖 features
    ├── platform/              # PlatformAdapter + ffprobe/ffmpeg 执行器 + 引擎 + 取消管理器
    ├── providers/             # core_providers.dart(共享 provider 注册表,实现由 main 注入)
    ├── repositories/          # 内存过渡仓储 + Isar schema + settings 实现
    └── widgets/               # 跨功能复用组件(进度条、按钮等)
```

## 五、代码质量规范

### 5.1 格式化

- 一律 `dart format .` 后提交,禁止手调格式。
- 行宽默认 80,长链式调用换行。

### 5.2 静态分析

- `flutter analyze` **零告警、零错误**才算完成;`analysis_options.yaml` 使用 Flutter 官方 lints。

### 5.3 测试

- `flutter test` 必须全绿。
- 关键覆盖点:
  - 转换参数 → FFmpeg 命令构造(纯 Dart 单元测试,不依赖真机)
  - `-progress pipe:1` 输出解析(进度百分比)
  - 历史记录 CRUD(Isar 内存实例测试)
  - 核心页面 Widget 测试(路由可达、无异常)
- 不要求 100% 覆盖率,但核心逻辑(命令构造、进度解析)必须有测试。

### 5.4 错误处理

- **异常分层**:定义业务异常(如 `ConversionException`、`FilePickException`),捕获 FFmpeg 非零退出码并包装。
- FFmpeg 失败时:`logger.e()` 记录完整 stderr,UI 展示用户可读的中文错误信息,不泄露原始路径。
- 异步操作(Riverpod `AsyncNotifier`)统一用 `AsyncValue` 状态机管理 loading / error / data。
- 所有 IO 与转码操作放 `compute` / isolate,避免阻塞 UI 线程。

### 5.5 命名与风格

- 文件 `snake_case.dart`;类 `PascalCase`;变量/方法 `camelCase`;常量前缀 `k`。
- 私有成员前缀 `_`;对外 API 一律写 Dartdoc 注释;核心类必须带中文注释说明职责。

### 5.6 功能层与 UI 层分离(强制红线)

- **功能层**(`features/<模块>/application/`):用例、控制器、状态逻辑,纯 Dart,禁止 `import 'package:flutter/material.dart'` 与 `widgets.dart`,可独立单测。
- **UI 层**(`features/<模块>/presentation/` 与 `shared/widgets/`):只渲染与转发事件,禁止业务逻辑(校验/计算/状态转换),禁止直调仓储与基础设施。
- 依赖单向:`presentation → application`;功能层不感知 UI。跨模块协作经 application 用例(见 docs/04-系统架构.md §4.7)。

## 六、MP4 → GIF 转换设计

> 全平台一致性:以下命令与参数逻辑由 `FFmpegEngine` 接口承载,六端行为一致;各平台实现仅负责"如何执行命令",不得改动参数语义。Android/Linux/Windows/macOS 与 iOS 直接用同一命令参数构造器(复用测试),Web 端命令结构一致但走 WASM 执行路径。

### 6.1 默认命令(两遍调色板法,质量最佳)

```bash
# 第一遍:生成全局调色板
ffmpeg -i in.mp4 -vf "fps=15,scale=480:-1:flags=lanczos,palettegen" -y palette.png
# 第二遍:应用调色板输出 GIF
ffmpeg -i in.mp4 -i palette.png -lavfi "fps=15,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse" -y out.gif
```

### 6.2 可调参数(存为默认配置,SharedPreferences 持久化)

- 帧率 `fps`(默认 15)
- 宽度 `scale`(默认 0 = 原图等比;-1 保持比例)
- 高度 `scale`(默认 0 = 原图等比;与宽度同时指定时按指定尺寸输出,允许变形)
- 起止时间 `-ss` / `-to`
- 质量模式:标准(单遍) / 高质(调色板两遍)

### 6.3 进度与取消

- 以 `-progress pipe:1` 解析 `out_time_us` → 计算百分比,经 `Stream` 推送给 UI。
- 取消 = 终止子进程,清理临时文件(palette.png、半成品 gif)。
- 转换前后在 Isar 中登记记录,状态:等待中 / 进行中 / 完成 / 失败 / 已取消。

## 七、常用命令

```bash
flutter pub get                                   # 拉取依赖
dart run build_runner build --delete-conflicting-outputs   # 生成 freezed/json/isar/riverpod 代码
flutter analyze                                   # 静态分析(原目录直接跑,项目路径已 ASCII)
flutter test                                      # 测试(原目录直接跑)
dart format .                                     # 格式化
flutter run -d linux                              # 桌面运行(按平台替换 -d)
dart run tool/convert_check.dart                  # P3 阶段门:真实转码 SHA-256 一致性(依赖系统 ffmpeg)
bash tool/gen_fixtures.sh                         # 重新生成集成测试夹具视频(test/fixtures/videos)
bash tool/ascii_sync.sh                           # (可选)同步 ASCII 副本,历史遗留工具
```

### 7.x 路径说明(2026-08-05 项目改名后)

- 项目根目录 `/home/yrz/chameleon_gif` 为 ASCII 路径,**`flutter analyze` / `flutter test` 均可在原目录直接跑**(历史上项目曾位于中文路径 `/home/yrz/mp4转git`,analysis server 会抛 FormatException,需经 `tool/ascii_sync.sh` 副本规避;脚本保留备用于其他非 ASCII 环境)。
- 真实样本验证脚本:`dart run tool/probe_check.dart`(不走 analysis server)。

## 八、注意事项(避坑)

- **不要**升级 Isar 到 4.0-dev;维持 `isar_community ^3.3.2` 系列(R-04 预案已启用,替换官方包需重新评审);`ffmpeg_kit_flutter` 仅为 iOS 预留,不进入 MVP。
- FFmpeg 引擎分平台:**桌面(Linux/Windows)= 系统 ffmpeg/ffprobe 二进制**,Android = `ffmpeg_kit_flutter_minimal`(该 fork 无桌面实现,已实证);禁止在业务层写 `Platform.isXxx` 分支(差异归 PlatformAdapter,见 docs/08-FFmpeg设计.md §8.3.8;选型依据 docs/03-技术选型.md)。
- 转码输出一致性:三平台同参输出需 SHA-256 一致(见 docs/14-测试计划.md §14.6)。
- Web/iOS 的适配注意点(WASM 内存上限、iOS 沙盒)为预留评估项,落地时再实现,当前不写相关代码。
- 生成的 `.g.dart` / `.freezed.dart` / `*.isar.dart` 文件不提交修改,只随生成器版本变化整体更新。
- 大文件转换占用 CPU 高,转换中不允许重复启动同源转换;UI 必须禁用相关入口。
- 转换产物默认输出到系统临时目录,完成后提示用户"另存为"(file_selector)。

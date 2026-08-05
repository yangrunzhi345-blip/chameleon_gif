# 🦎 Chameleon Gif

一个把视频和图片做成 GIF 的跨平台桌面工具,支持 Linux / Windows / Android。

## 它解决了什么问题

转 GIF 这件事,绕不开四个老问题:

**在线工具不放心。** 视频要上传到别人的服务器,文件一大就慢,隐私也没保障——你传上去的素材,别人拿去干嘛你根本不知道。Chameleon Gif 全程本地转码,文件不离开你的电脑,离线也能用,大文件也没有上传这一说。

**ffmpeg 不好用。** 转个 GIF 要手写 `palettegen`、`paletteuse` 一长串参数,还得记 `-ss`、`-to`、`scale` 各种语法;想把视频裁成中间一段,先得算好时间点;想调画质,参数一错就报错,报错信息还看不懂。这个应用把这些全可视化:时间轴上拖一下就是选区,帧率尺寸下拉框里选,输出效果转换前就能预览,一条命令都不用记。

**画质也常被忽略。** 不少工具单遍直接输出,GIF 颜色断层、噪点多,高动态画面尤其明显。Chameleon Gif 默认两遍调色板法:先全片采样生成全局调色板,再精确映射输出,颜色过渡平滑;要速度可以切标准模式。

**图片模式有坑。** 多张尺寸不一的图片合成 GIF,很多工具会把图直接拉伸成同一尺寸——1024×1024 的方图和 1080×1920 的竖图混在一起,竖图被硬压成方的,画面变形,人脸都拉长。Chameleon Gif 的做法是统一画布、每张图保持自身比例、多余区域透明填充居中,任何尺寸混排都不变形。更进一步,每张图还能单独设置缩放倍数、宽度、高度:想让某张图在动画里更突出,点齿轮进去调,实时预览,不影响其他图;显式指定宽高时按你的要求精确输出,规则你说了算。

**转个 GIF 的流程很零碎。** 一次想转好几段视频,得一段一段来;转完的记录没人存,想再转一次得重新配置所有参数;转了一半程序崩了,前面的功夫全白费。Chameleon Gif 把这三件事都补齐了:任务队列批量排队转(双并发)、历史记录一键重转(当时的参数原样复现)、转换中途崩溃自动恢复重新排队。

一句话总结:在线工具的隐私问题、命令行工具的易用性问题、图片模式的变形问题、转换流程的零碎问题——这四块,它都解决掉了。

什么时候用它最合适?做表情包、给教程配动图、把游戏或录屏片段转出来分享、设计师给交互演示配图……这类需求它都管。偶尔转一次,开箱即用;天天要转的人,队列和历史能省下大量重复操作。

它不做什么也很明确:不录屏、不做视频格式转换、不做在线分享——定位就是纯粹的"视频和图片 → GIF"。macOS 和 Web 版在规划中,当前首发 Linux、Windows、Android。

对了,名字叫 Chameleon(变色龙),因为做 GIF 这件事,色彩是灵魂——变色龙,颜色多嘛。

## 功能特性

### 视频 → GIF

- MP4 导入后实时预览,时间轴精确选起止区间(毫秒级)
- 帧率(8–60 fps)、宽高缩放、循环次数、质量模式自由组合
- 默认采用**两遍调色板法**(先全片采样生成全局调色板,再应用输出),颜色过渡平滑;可切换标准单遍模式提速
- 实时进度(百分比 + 剩余时间预估),转换中可取消,临时文件自动清理

### 多图片 → GIF(帧动画)

- PNG / JPG / WebP 按顺序合成,上移/下移/删除/追加调整
- 每图停留时长(毫秒,下限 `ceil(1000/fps)` 防 0 帧图)、帧率、循环、质量独立配置
- **统一画布 + 不扭曲**:画布尺寸 = 表单指定宽高 / 首图尺寸 / 按首图比例推算;未精细控制的图保持自身比例 contain 于画布,透明 pad 居中(`format=rgba` 保证真透明,`setsar=1` 归一 SAR)
- **每张图精细控制**:齿轮入口 → 全屏控制页,单图设置等比缩放倍数/宽度/高度,实时预览最终呈现;双边显式指定按精确尺寸输出(允许变形,用户决定),单边/倍率保持比例;min 钳制防超画布;参数随任务/历史持久化,重转原样复现

### 队列与历史

- 任务队列双并发槽调度,失败指数退避重试(≤2 次),崩溃恢复扫描未完成任务重新排队
- 历史记录(Isar 持久化):详情、一键重转、删除、清空
- Android 完成自动存相册;桌面完成弹窗可打开文件夹/另存为

## 平台支持

| 平台 | 状态 | 转码方式 |
|------|------|----------|
| Linux | ✅ 首发(主要开发平台) | 系统 ffmpeg/ffprobe 二进制 |
| Windows | ✅ 首发 | 系统 ffmpeg/ffprobe 二进制 |
| Android | ✅ 首发 | 内置 FFmpegKit 原生库(随包分发) |
| macOS / Web / iOS | 🔒 预留 | 架构已兼容,后续版本落地 |

桌面端需系统安装 ffmpeg/ffprobe(缺失时应用明确提示);Android 端无需额外安装。

## 从源码构建

环境要求:Flutter SDK >= 3.38、Dart >= 3.10,桌面端运行需系统 ffmpeg。

```bash
git clone <仓库地址> && cd chameleon_gif

flutter pub get                                                       # 拉依赖
dart run build_runner build --delete-conflicting-outputs              # 生成 freezed/isar/riverpod 代码
flutter run -d linux                                                  # 桌面运行(Linux;按平台换 -d)
```

开发常用命令:

```bash
dart format .                            # 格式化
flutter analyze                          # 静态分析(要求零告警)
flutter test                             # 单元测试(要求全绿)
dart run tool/probe_check.dart           # ffprobe 链路自检
dart run tool/convert_check.dart         # 真实转码 SHA-256 一致性验证
```

## 技术架构

### 分层结构

代码按"组合根 → 功能模块 → 领域层 → 基础设施"四层组织,依赖方向单向:

```
app(组合根)     MaterialApp · GoRouter 路由 · 页面壳(跨模块 UI 组合收敛于此)
features(模块)  converter · preview · export · history · task_queue · timeline · import
                每个模块内部:application(纯 Dart 功能层)→ infrastructure → presentation(UI 层)
domain(领域)    实体 · 值对象 · 端口接口 · 异常层级(零 Flutter 依赖)
shared(基础)    PlatformAdapter · FFmpegEngine · Isar 仓储 · 引擎执行器
```

### 关键设计决策

- **转码引擎接口抽象**(`FFmpegEngine`):桌面调系统 ffmpeg 二进制(`Process`),Android 用内置 FFmpegKit 原生库,业务层零平台分支;平台差异全部收敛于 `PlatformAdapter`。macOS / Web(WASM)落地只需补实现。
- **命令构造是纯函数**(`GifCommandBuilder`):输入 `GifSetting + VideoInfo/ImageGifSource` 输出命令列表。图片模式命令:画布规则 → 每图链(默认 contain + 透明 pad / 控制链双边变形或等比 + min 钳制)→ concat → 两遍调色板。快照测试锁定命令格式。
- **状态管理用 Riverpod 3**(代码生成):会话级 autoDispose 自动清理;进度高频数据走 200ms 节流 Stream,不重建页面;`TaskManager` 为独立状态机(双并发槽、重试、崩溃恢复),只调度不转码。
- **持久化用 Isar**(本地 NoSQL):任务、历史、每图精细控制参数(`perImageControlsJson` 可空 String 列,老数据零迁移)持久化,支撑崩溃恢复与历史重转参数复现。
- **进度与错误解析器独立**:`-progress pipe:1` 输出解析为百分比;FFmpeg 失败分类为领域异常(源缺失/损坏、磁盘满、输出冲突、调色板失败等,各有错误码),UI 只展示中文文案不泄露路径。
- **功能层/UI 层强制分离**:功能层纯 Dart 可脱离 Widget 直接单测;UI 层只渲染与转发事件,画布推导在 `ImageGifController.canvasSize`,预览呈现比例计算在 `control_target.dart` 纯函数,UI 不承载业务计算。

## 质量保障

- `flutter analyze` 零告警为提交门槛(Flutter 官方 lints)
- `flutter test` 全绿,549 个测试:命令构造快照(视频/图片两路)、进度解析、Isar 仓储往返、控制器逻辑、页面 Widget 测试
- 三平台同参数输出 SHA-256 一致性验证(`tool/convert_check.dart`)
- 生成式代码(freezed / isar / riverpod)只经 build_runner 产出,不手改

架构细节、设计取舍、版本锁定表在 `docs/` 目录有 17 篇文档(需求、选型、架构、FFmpeg 设计、测试计划、发布计划等)。

## 接下来做什么

- **V2 专业版**:播放速度 / 倒放 / 镜像 / 旋转 / 裁剪、色彩数量控制、抖动算法、大小预估强化
- **V3 生态版**:macOS / Web 落地、多语言、预设系统、自动更新、插件系统、WebP / APNG 导出

## 贡献

- 开工前先 `git pull` 同步最新代码,从 main 切功能分支(`feat/<分支名>`)
- 提交信息格式:`type(scope): 中文描述`(`feat` / `fix` / `refactor` / `docs` / `chore` / `test` / `perf`)
- 完成门槛:`dart format .` → `flutter analyze` 零告警 → `flutter test` 全绿

## 许可证

[GPL-3.0](LICENSE)。

选型依据:Android 端内置 FFmpegKit 原生库含 GPL-3.0 组件(静态链接);桌面端调系统 ffmpeg 子进程不构成衍生作品;media_kit 播放内核为 MIT 宽松许可。

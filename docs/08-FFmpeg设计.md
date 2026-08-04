# 08 FFmpeg 设计(核心章节)

> 模块设计:[06-模块设计](06-模块设计.md) M07/M08 · 数据库:[07-数据库设计](07-数据库设计.md) · 异常处理:[11-开发规范](11-开发规范.md) §5

## 8.1 设计原则

1. **UI 不直接触碰 FFmpeg**:所有转码调用经 `TaskManager(TaskQueue 模块)` → `FFmpegService(converter 模块)`,UI 只订阅任务状态流。
2. **命令与执行分离**:`CommandBuilder` 纯函数构造命令,可单元测试;执行器只负责跑命令。
3. **可取消、可恢复、可重试**:取消 = 子进程终止 + 临时文件清理;恢复 = 任务持久化,重启重新排队;重试 = 可重试错误自动重试 ≤2 次。
4. **平台差异收敛于 PlatformAdapter**:业务层感知不到"桌面 vs Android"。

## 8.2 组件总览

```
                    ┌───────────────────────────────┐
                    │       TaskManager(M07)        │ 调度/状态机/重试/恢复
                    └──────────────┬────────────────┘
                                   │ 任务实例(queued→running)
                    ┌──────────────▼────────────────┐
                    │       FFmpegService(M08)      │ 编排一次转换
                    └──┬────────┬─────────┬─────────┴──┐
                       │        │         │            │
              ┌────────▼─┐ ┌────▼────┐ ┌──▼──────┐ ┌───▼──────┐
              │CommandBuilder│ProgressParser│LogParser│ErrorHandler│
              └────────┬─┘ └────┬────┘ └──┬──────┘ └───┬──────┘
                       │        │         │            │
                    ┌──▼────────▼─────────▼────────────▼─────────┐
                    │           FFmpegEngine(接口+实现)          │
                    │   ProcessEngine(桌面) / FFmpegKitEngine(Android) │
                    ├──────────────┬─────────────────────────────┤
                    │CancellationManager│     PlatformAdapter    │
                    └──────────────┴─────────────────────────────┘
                          │                     │
            桌面:系统 ffmpeg/ffprobe 二进制   Android:ffmpeg_kit_flutter_minimal
```

## 8.3 组件详设

### 8.3.1 FFmpegEngine(接口)

```dart
/// 一次转换的请求(命令已由 CommandBuilder 生成)
class ConvertRequest {
  final List<String> command;     // ffmpeg 参数列表(不含可执行名)
  final String workDir;           // 临时目录
  final List<String> tempFiles;   // 需清理的临时文件(palette 等)
}

class ConvertResult {
  final int exitCode;
  final Duration elapsed;
  final int outputSizeBytes;
}

abstract class FFmpegEngine {
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  });
}
```

### 8.3.2 CommandBuilder(纯函数,可单测)

- 输入 `GifSetting + VideoInfo` → 输出 `List<String>`(两遍 palette 法的两次命令)
- **标准模式(单遍)**:

```bash
ffmpeg -ss <start> -to <end> -i <in.mp4>
  -vf "fps=15,scale=480:-1:flags=lanczos"
  -progress pipe:1 -y -loop 0 <out.gif>
```

- **Palette 模式(两遍,默认)**:

```bash
# 第一遍:生成调色板
ffmpeg -ss <start> -to <end> -i <in.mp4>
  -vf "fps=15,scale=480:-1:flags=lanczos,palettegen=max_colors=256"
  -y <work>/palette.png
# 第二遍:应用调色板(loop 按参数映射规则两遍均携带)
ffmpeg -ss <start> -to <end> -i <in.mp4> -i <work>/palette.png
  -lavfi "fps=15,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5"
  -progress pipe:1 -y -loop <n> <out.gif>
```

- 参数映射规则(设计契约,单测断言):
  - `fps` → `fps=<fps>`;`width=0` 时省略 scale(原图)
  - `-ss/-to` 前置(快速定位,精确到帧需求时后置评审)
  - `loop` → `-loop <n>`;`reverse` → `-vf "reverse"`(需缓存,大文件评估)
  - `mirror/rotation/crop` → 滤镜链拼接,顺序固定:`crop→mirror→rotate→scale→fps`
  - `speed` → `setpts=PTS/<speed>`
  - V3:codec 分支(`-f webp` / APNG muxer)在此扩展

### 8.3.3 ProgressParser(纯函数,可单测)

- 输入:`-progress pipe:1` 的 stdout 行流
- 输出:`TaskProgress` 增量
- 解析键:`out_time_us`(→ 当前时间)、`total_size`(→ 已写字节)、`speed`(→ 实时速度)
- 百分比 = `out_time / (end - start)`(分母由 CommandBuilder 传入);speed 恒 0 时降级为基于已耗时的模糊预估
- **鲁棒性**:行解析失败不中断(丢弃该行);编码语言差异(非英文 FFmpeg)不敏感,只解析键值

### 8.3.4 LogParser(纯函数)

- 输入:stderr 行流;输出:分级日志回调
- 规则:`[error]`/`Error`/`Invalid` → 错误;`[warning]`/`Warning` → 警告;其余 → 信息(截断长行)
- 与 ErrorHandler 联动:错误行聚合供退出码语义不足时补充判断

### 8.3.5 ErrorHandler

| 退出码/特征 | 领域异常 | 用户提示(中文) |
|-------------|----------|----------------|
| exit 127 / 找不到二进制 | `FFmpegMissingException` | "FFmpeg 组件缺失,请重装应用" |
| `No such file or directory`(输入) | `SourceMissingException` | "源文件不存在或已被移动" |
| `Invalid data found` / `moov` 缺失 | `SourceBrokenException` | "视频文件损坏或格式异常" |
| `No space left on device` | `DiskFullException` | "磁盘空间不足,请清理后重试" |
| `Permission denied` | `PermissionException` | "没有文件写入权限" |
| `Output file already exists`(未加 -y 场景) | `OutputConflictException` | "输出文件已存在" |
| 退出码 1 且含 palette 关键词 | `PaletteException` | "调色板生成失败" |
| 其他非 0 | `EncodeException` | "转换失败(错误码 X),日志:…" |

- 错误码编码:`GIF_<EXITCODE>_<KIND>`,入库 Task.errorCode(见 [07-数据库设计](07-数据库设计.md) §7.3.1)

### 8.3.6 CancellationManager

- `CancelToken`:状态 atomic(单线程异步)标记
- 取消动作:① 标记 token → ② 请求 `process.kill()` → ③ 等待子进程退出(3s 超时)→ ④ `process.kill(force)` → ⑤ 幂等清理 tempFiles(存在才删)
- 中断清理:应用退出时 `AppLifecycleListener` 触发同流程;崩溃场景由下次启动的恢复流程兜底
- **幂等保证**:任何路径重复取消不产生副作用

### 8.3.7 TaskManager(调度)

- 队列结构:FIFO + 并发槽(1,P3 单任务;P6 提至 2);提供 `cancel/retry/priority`
- 重试:仅 `SourceBrokenException`、`PaletteException` 之外的可重试错误;指数退避 2s/4s;retryCount 入库
- 恢复:启动时 `TaskRepository.pending()` 扫描 `queued/running` → 重置 queued 重新入队(见 [07-数据库设计](07-数据库设计.md) §7.3.1)
- 完成流程:更新任务 → 生成 ExportHistory 快照 → 通知(桌面:系统通知/应用内;Android:NotificationChannel)

### 8.3.8 PlatformAdapter(平台差异收敛)

| 差异点 | 桌面(Linux/Windows) | Android |
|--------|---------------------|---------|
| FFmpeg 二进制 | **系统 ffmpeg/ffprobe 二进制**(`dart:io Process`,P1 已实证 ffmpeg_kit_flutter_minimal 无桌面实现;缺失→`FFmpegMissingException`) | ffmpeg_kit_flutter_minimal 内嵌库(本轮未验证,P8 三平台清单确认) |
| 工作/输出目录 | 用户目录(可写) | 应用专属目录 `getExternalFilesDir` + MediaStore(V3 写公共相册) |
| 路径表示 | 原生路径 | content:// 与文件路径双模 |
| 进程信号 | `process.kill` 直接 | 同 API,生命周期后台限制 |
| 输出通知 | 系统通知 | NotificationChannel 常驻进度条 |

**统一方式**:`FFmpegEngine` 接口 + `PlatformAdapter` 内部完成差异,业务层零分支(见 [09-状态管理](09-状态管理.md) 平台 Provider)。

## 8.4 一次转换的时序(文字时序图)

```
TaskManager        FFmpegService        CommandBuilder        Engine            用户
    │ submit()          │                     │                 │                │
    ├──────────────────►│                     │                 │                │
    │                   │───build()──────────►│                 │                │
    │                   │◄──[cmd1, cmd2]──────┤                 │                │
    │                   │──convert(req)───────────────────────►│                │
    │                   │                     │         执行 cmd1(palette)        │
    │◄─progress─────────│◄─onProgress─────────────────────────┤                │
    │◄─progress─────────│◄─onProgress─────────────────────────┤                │
    │                   │                     执行 cmd2(encode)                  │
    │◄─progress─────────│◄─onProgress─────────────────────────┤                │
    │                   │                     │         [用户点取消]              │
    │                   │──cancel()─────────────────────────────────────────────►│
    │                   │                     │         kill+清理 ──┐            │
    │◄─cancelled────────│◄─result(cancelled)──┴──────────────────────┘            │
    │ 状态→cancelled    │                     │                 │                │
```

## 8.5 可维护 / 可扩展 / 可取消 / 可恢复 / 可重试 — 保障清单

| 质量属性 | 设计落点 |
|----------|----------|
| 可维护 | CommandBuilder/ProgressParser 纯函数 + 单测;组件单一职责;接口契约文档化(§8.3) |
| 可扩展 | 命令模型驱动(参数→命令的映射表),新增参数/格式只改 CommandBuilder;引擎接口化可换实现 |
| 可取消 | CancelToken 贯穿 Engine→Process;CancellationManager 幂等清理 |
| 可恢复 | 任务持久化 + 启动恢复扫描;临时文件命名含 taskId,恢复时按 taskId 兜底清理 |
| 可重试 | TaskManager 重试策略 + retryCount 持久化;错误分类决定可重试性 |

## 8.6 平台适配(Android 与桌面统一)

- **调用方式**:桌面(Linux/Windows)经 `dart:io Process` 调系统 ffmpeg/ffprobe 二进制;Android 经 `ffmpeg_kit_flutter_minimal` Dart API(内嵌原生库)。两条路径均收敛于 `FfprobeExecutor`/`FFmpegEngine` 抽象(见 §8.3.8),命令参数构造器与解析器完全复用。
- **界面一致**:UI 层经 `PlatformAdapter` 获取"临时目录/导出目录/执行器",不写任何 `Platform.isAndroid` 分支于业务层。
- **验证**:三平台同一输入同一参数,输出文件 SHA-256 一致(见 [14-测试计划](14-测试计划.md) 跨平台清单;桌面已实测 P1 解析链路)。

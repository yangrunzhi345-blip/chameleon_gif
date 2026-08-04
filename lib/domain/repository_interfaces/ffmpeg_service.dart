import '../entities/video_info.dart';
import '../value_objects/gif_setting.dart';
import '../value_objects/task_progress.dart';
import 'ffmpeg_engine.dart';

/// FFmpeg 转码服务端口(编排一次"设置 → GIF 输出"的完整转换)。
///
/// 职责(§8.2 图):命令构造 → 逐命令执行(engine)→ stdout 行 → 进度解析
/// → stderr 行 → 日志分级 + 全文聚合 → 非 0 退出 → 错误分类。
/// TaskManager 依赖本端口(禁止直触 [FFmpegEngine]/CommandBuilder,
/// 见 docs/05 §5.3 依赖矩阵)。
abstract interface class FFmpegService {
  /// 执行转换;成功返回结果,失败抛领域异常([ErrorHandler] 分类结果)。
  ///
  /// [workDir] 为含 taskId 的临时目录(命令构造与清理的基础);
  /// [outputPath] 为 GIF 输出完整路径。取消经 [cancelToken]:
  /// 取消后返回 [ConvertResult.cancelled] = true,不抛异常。
  Future<ConvertResult> convert({
    required GifSetting setting,
    required VideoInfo video,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  });
}

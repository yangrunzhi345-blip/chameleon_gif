import '../../../domain/entities/export_task.dart';

/// 导出会话生命周期态。
enum ExportLifecycle { idle, exporting, done, failed }

/// 导出会话状态(docs/09-状态管理.md §9.2 层次二,autoDispose,
/// 文档命名 ExportFormState)。
///
/// 含生命周期(lifecycle/taskId/task/...)与参数表单(fps/width/loop/
/// start/end/outputDir/formError)两部分;高频进度量不进入本状态,
/// 经 exportProgressProvider(200ms 节流流)独立消费。
///
/// 生命周期转换一律经 [copyWith](表单值恒保留);命名构造器仅供
/// 初始态与测试。
class ExportFormState {
  const ExportFormState._({
    required this.lifecycle,
    this.taskId,
    this.task,
    this.outputSizeBytes,
    this.errorMessage,
    this.fps = 15.0,
    this.width = 480,
    this.loop = 0,
    this.start = Duration.zero,
    this.end,
    this.outputDir,
    this.formError,
  });

  const ExportFormState.idle() : this._(lifecycle: ExportLifecycle.idle);

  const ExportFormState.exporting(int taskId)
    : this._(lifecycle: ExportLifecycle.exporting, taskId: taskId);

  const ExportFormState.done(ExportTask task, int outputSizeBytes)
    : this._(
        lifecycle: ExportLifecycle.done,
        task: task,
        outputSizeBytes: outputSizeBytes,
      );

  const ExportFormState.failed(String errorMessage)
    : this._(lifecycle: ExportLifecycle.failed, errorMessage: errorMessage);

  final ExportLifecycle lifecycle;

  /// 进行中任务 id(exporting 态)。
  final int? taskId;

  /// 已完成任务(done 态)。
  final ExportTask? task;

  /// 输出文件字节数(done 态;功能层读文件,UI 仅展示)。
  final int? outputSizeBytes;

  /// 会话级错误文案(failed 态)。
  final String? errorMessage;

  // ---- 参数表单(导出会话内,导出中锁定) ----

  /// 输出帧率(1–60)。
  final double fps;

  /// 输出宽度(0 = 原图等比;钳制 0–4096)。
  final int width;

  /// 循环次数(0 = 无限循环;钳制 0–100)。
  final int loop;

  /// 输出起点。
  final Duration start;

  /// 输出终点(null = 到视频结尾)。
  final Duration? end;

  /// 导出目录(null = 系统临时目录)。
  final String? outputDir;

  /// 表单级错误(时间格式非法/目录选择失败等;非空时禁用导出)。
  final String? formError;

  /// 未传标记(允许显式置 null:end/errorMessage/formError)。
  static const _unset = Object();

  ExportFormState copyWith({
    ExportLifecycle? lifecycle,
    Object? taskId = _unset,
    Object? task = _unset,
    Object? outputSizeBytes = _unset,
    Object? errorMessage = _unset,
    double? fps,
    int? width,
    int? loop,
    Duration? start,
    Object? end = _unset,
    Object? outputDir = _unset,
    Object? formError = _unset,
  }) {
    return ExportFormState._(
      lifecycle: lifecycle ?? this.lifecycle,
      taskId: identical(taskId, _unset) ? this.taskId : taskId as int?,
      task: identical(task, _unset) ? this.task : task as ExportTask?,
      outputSizeBytes: identical(outputSizeBytes, _unset)
          ? this.outputSizeBytes
          : outputSizeBytes as int?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      fps: fps ?? this.fps,
      width: width ?? this.width,
      loop: loop ?? this.loop,
      start: start ?? this.start,
      end: identical(end, _unset) ? this.end : end as Duration?,
      outputDir: identical(outputDir, _unset)
          ? this.outputDir
          : outputDir as String?,
      formError: identical(formError, _unset)
          ? this.formError
          : formError as String?,
    );
  }

  /// 导出中锁定:表单更新与导出按钮均拒绝。
  bool get locked => lifecycle == ExportLifecycle.exporting;
}

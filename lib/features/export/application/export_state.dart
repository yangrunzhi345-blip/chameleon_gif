import '../../../domain/entities/export_task.dart';

/// 导出会话生命周期态。
enum ExportLifecycle { idle, exporting, done, failed }

/// 导出会话状态(docs/09-状态管理.md §9.2 层次二,autoDispose)。
///
/// 普通手写类(状态极简,无 JSON 需求,与 PreviewState 风格一致);
/// 高频进度量不进入本状态,经 exportProgressProvider(200ms 节流流)独立消费。
class ExportUiState {
  const ExportUiState._({
    required this.lifecycle,
    this.taskId,
    this.task,
    this.outputSizeBytes,
    this.errorMessage,
  });

  const ExportUiState.idle() : this._(lifecycle: ExportLifecycle.idle);

  const ExportUiState.exporting(int taskId)
    : this._(lifecycle: ExportLifecycle.exporting, taskId: taskId);

  const ExportUiState.done(ExportTask task, int outputSizeBytes)
    : this._(
        lifecycle: ExportLifecycle.done,
        task: task,
        outputSizeBytes: outputSizeBytes,
      );

  const ExportUiState.failed(String errorMessage)
    : this._(lifecycle: ExportLifecycle.failed, errorMessage: errorMessage);

  final ExportLifecycle lifecycle;

  /// 进行中任务 id(exporting 态)。
  final int? taskId;

  /// 已完成任务(done 态)。
  final ExportTask? task;

  /// 输出文件字节数(done 态;功能层读文件,UI 仅展示)。
  final int? outputSizeBytes;

  /// 用户可读错误(failed 态)。
  final String? errorMessage;
}

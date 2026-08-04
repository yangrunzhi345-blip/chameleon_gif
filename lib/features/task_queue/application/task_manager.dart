import 'dart:async';
import 'dart:io';

import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/export_history.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/domain_exception.dart';
import '../../../domain/exceptions/palette_exception.dart';
import '../../../domain/exceptions/source_broken_exception.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../../domain/repository_interfaces/history_repository.dart';
import '../../../domain/repository_interfaces/task_repository.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_progress.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/platform/platform_adapter.dart';
import '../../converter/application/cancellation_manager.dart';

/// 任务调度器(单并发槽 FIFO,docs/06 §6.3、docs/08 §8.3.7)。
///
/// 状态机:queued → running → completed|failed|cancelled;failed → queued(重试,
/// 仅非 SourceBroken/Palette 错误,指数退避 2s/4s,retryCount ≤ 2)。
/// 启动恢复:[start()] 扫描仓储 pending(queued/running)→ 重置 queued 重排队。
/// 完成流程:任务落终态 + 输出路径 → 生成 [ExportHistory] 快照入库 → 事件流通知。
///
/// 取消:[cancel] 经 [CancellationManager] 标记令牌(引擎侧终止进程)并幂等清理。
class TaskManager {
  TaskManager({
    required TaskRepository taskRepository,
    required HistoryRepository historyRepository,
    required FFmpegService ffmpegService,
    required PlatformAdapter platformAdapter,
    required AppLogger logger,
    Future<void> Function(Duration)? retryDelay,
  }) : _taskRepository = taskRepository,
       _historyRepository = historyRepository,
       _ffmpegService = ffmpegService,
       _platformAdapter = platformAdapter,
       _logger = logger,
       _retryDelay = retryDelay ?? Future<void>.delayed;

  final TaskRepository _taskRepository;
  final HistoryRepository _historyRepository;
  final FFmpegService _ffmpegService;
  final PlatformAdapter _platformAdapter;
  final AppLogger _logger;
  final Future<void> Function(Duration) _retryDelay;

  static const maxRetryCount = 2;

  final List<int> _queue = [];
  int? _runningId;
  final Map<int, VideoInfo> _videos = {};
  final Map<int, CancelToken> _tokens = {};
  final Map<int, CancellationManager> _cancelManagers = {};
  bool _started = false;
  DateTime? _lastProgressWrite;

  final _progressController = StreamController<TaskProgress>.broadcast();
  final _taskEvents = StreamController<ExportTask>.broadcast();

  /// 实时进度流(UI 消费,外部可再节流)。
  Stream<TaskProgress> get progressStream => _progressController.stream;

  /// 任务状态变化流(queued→running→终态,UI 列表与完成弹窗消费)。
  Stream<ExportTask> get taskEvents => _taskEvents.stream;

  /// 当前全部任务(按 id 序)。
  Future<List<ExportTask>> get tasks => _taskRepository.all();

  bool get _busy => _runningId != null;

  /// 提交转换任务(FIFO 入队;若空闲立即启动)。
  ///
  /// [setting.end] 缺省时装配为 [video.duration](公共 API 自洽,直连不产生
  /// `-to 00:00:00.000` 空窗口)。
  Future<int> submit(GifSetting setting, VideoInfo video) async {
    final effective = setting.end == null
        ? setting.copyWith(end: video.duration)
        : setting;
    final task = ExportTask(
      id: 0,
      videoPath: video.path,
      settings: effective,
      state: TaskState.queued,
      createdAt: DateTime.now(),
    );
    final id = await _taskRepository.add(task);
    _videos[id] = video;
    _queue.add(id);
    _logger.i('任务入队: id=$id path=${video.path}');
    await _emitTask(task);
    unawaited(_pump());
    return id;
  }

  /// 取消任务:queued 直接终态;running 触发令牌(引擎终止)+ 幂等清理。
  Future<void> cancel(int id) async {
    final task = await _taskRepository.byId(id);
    if (task == null || task.state.isFinal) return; // 终态幂等
    final manager = _cancelManagers[id];
    if (task.state == TaskState.running && manager != null) {
      await manager.cancel();
      return; // 转换侧检测令牌后走 cancelled 收尾
    }
    _queue.remove(id);
    _videos.remove(id); // 未执行的排队任务,释放提交时缓存的元数据
    await _update(task.copyWith(state: TaskState.cancelled));
    _emitTask(task);
  }

  /// 重试失败任务(failed → queued,retryCount 递增由执行侧处理)。
  Future<void> retry(int id) async {
    final task = await _taskRepository.byId(id);
    if (task == null || task.state != TaskState.failed) return;
    await _update(task.copyWith(state: TaskState.queued));
    _queue.add(id);
    _logger.i('任务重试入队: id=$id');
    await _emitTask(task);
    unawaited(_pump());
  }

  /// 启动恢复:扫描仓储 pending → 全部重置 queued 重排队(崩溃恢复,§8.3.7)。
  /// 幂等:重复调用不重复入队。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final pending = await _taskRepository.pending();
    if (pending.isEmpty) return;
    _logger.i('恢复扫描: ${pending.length} 个待恢复任务重新排队');
    for (final task in pending) {
      await _update(task.copyWith(state: TaskState.queued, errorCode: null));
      _queue.add(task.id);
      await _emitTask(task);
    }
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_busy || _queue.isEmpty) return;
    final id = _queue.removeAt(0);
    _runningId = id;
    await _run(id);
  }

  Future<void> _run(int id) async {
    final task = await _taskRepository.byId(id);
    if (task == null) {
      _runningId = null;
      return;
    }
    // 提交时携带的完整 video;重试/恢复路径 _videos 已消费,以 settings 兜底
    // (width 取设置宽度而非 0:保证 scale 滤镜不因兜底缺失而输出原始分辨率;
    // 完整元数据持久化留 P5 Isar 仓储)
    final video =
        _videos.remove(id) ??
        VideoInfo(
          path: task.videoPath,
          formatName: '',
          duration: task.settings.end ?? Duration.zero,
          width: task.settings.width,
          height: 0,
          codec: '',
        );
    final workDir = '${_platformAdapter.systemTempDir}/gifforge_$id';
    final outputPath = '$workDir/out.gif';
    final token = CancelToken();
    _tokens[id] = token;
    _cancelManagers[id] = CancellationManager(
      token: token,
      tempFiles: ['$workDir/palette.png', outputPath],
      workDir: workDir,
    );
    await Directory(workDir).create(recursive: true);

    var current = task.copyWith(
      state: TaskState.running,
      startedAt: DateTime.now(),
    );
    await _update(current);
    _emitTask(current);
    _logger.i('任务开始执行: id=$id');

    try {
      final result = await _ffmpegService.convert(
        setting: task.settings,
        video: video,
        taskId: id,
        workDir: workDir,
        outputPath: outputPath,
        cancelToken: token,
        onProgress: (p) {
          _progressController.add(p);
          // 仓储进度写节流 500ms:ffmpeg 按帧输出,高频写对内存实现无碍,
          // Isar 化后避免每帧持久化;失败仅日志不阻断进度流
          final now = DateTime.now();
          if (_lastProgressWrite == null ||
              now.difference(_lastProgressWrite!) >=
                  const Duration(milliseconds: 500)) {
            _lastProgressWrite = now;
            unawaited(
              _update(
                current.copyWith(state: TaskState.running, progress: p.percent),
              ),
            );
          }
        },
      );
      if (result.cancelled || token.isCancelled) {
        await _finish(id, TaskState.cancelled);
        return;
      }
      // 成功:清理调色板临时文件(输出 out.gif 保留)
      await _cleanupPalette(workDir);
      final size = result.outputSizeBytes ?? 0;
      final history = ExportHistory(
        id: 0,
        videoPath: task.videoPath,
        outputPath: outputPath,
        settings: task.settings,
        durationMs: result.elapsed.inMilliseconds,
        outputSizeBytes: size,
        createdAt: DateTime.now(),
        sourceDurationMs: video.duration.inMilliseconds,
        outputFrameCount: _estimateFrameCount(task.settings, video),
      );
      await _historyRepository.add(history);
      _logger.i('任务完成: id=$id size=$size');
      await _finish(id, TaskState.completed, outputPath: outputPath);
    } catch (e, st) {
      _logger.e('任务执行失败: id=$id', error: e, stackTrace: st);
      if (token.isCancelled) {
        await _finish(id, TaskState.cancelled);
        return;
      }
      if (e is DomainException &&
          _isRetryable(e) &&
          task.retryCount < maxRetryCount) {
        final retryCount = task.retryCount + 1;
        await _update(
          current.copyWith(
            state: TaskState.queued,
            retryCount: retryCount,
            errorCode: e.errorCode,
          ),
        );
        _queue.add(id);
        _logger.w('任务退避重试: id=$id retry=$retryCount code=${e.errorCode}');
        _emitTask(current);
        await _retryDelay(Duration(seconds: 2 * retryCount));
        await _pump();
        return;
      }
      final errorCode = e is DomainException ? e.errorCode : 'GIF_UNKNOWN';
      final errorDetail = _truncate('$e');
      await _finish(
        id,
        TaskState.failed,
        errorCode: errorCode,
        errorDetail: errorDetail,
      );
    } finally {
      _tokens.remove(id);
      _cancelManagers.remove(id);
      _runningId = null;
      unawaited(_pump());
    }
  }

  Future<void> _finish(
    int id,
    TaskState state, {
    String? outputPath,
    String? errorCode,
    String? errorDetail,
  }) async {
    final task = await _taskRepository.byId(id);
    if (task == null) return;
    await _update(
      task.copyWith(
        state: state,
        outputPath: outputPath,
        errorCode: errorCode,
        errorDetail: errorDetail,
        finishedAt: DateTime.now(),
      ),
    );
    _emitTask(task);
  }

  Future<void> _update(ExportTask task) => _taskRepository.update(task);

  /// 完成/失败/取消事件广播(读取更新后的最新任务)。
  Future<void> _emitTask(ExportTask task) async {
    final latest = await _taskRepository.byId(task.id) ?? task;
    _taskEvents.add(latest);
  }

  bool _isRetryable(DomainException e) =>
      !(e is SourceBrokenException || e is PaletteException);

  /// 清理调色板临时文件(转换成功路径;取消路径经 CancellationManager)。
  Future<void> _cleanupPalette(String workDir) async {
    final palette = File('$workDir/palette.png');
    if (await palette.exists()) {
      await palette.delete();
    }
  }

  /// 输出帧数估算 = fps × 裁剪时长(恢复路径 video.duration 为兜底值)。
  int _estimateFrameCount(GifSetting setting, VideoInfo video) {
    final end = setting.end ?? video.duration;
    final seconds = (end - setting.start).inMilliseconds / 1000.0;
    return (setting.fps * seconds).round();
  }

  String _truncate(String s) => s.length > 500 ? '${s.substring(0, 500)}…' : s;
}

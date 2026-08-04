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
import '../../../shared/platform/cancellation_manager.dart';
import 'output_path.dart';

/// 任务调度器(双并发槽,P6-WP2;docs/06 §6.3、docs/08 §8.3.7)。
///
/// 状态机:queued → running → completed|failed|cancelled;failed → queued(重试,
/// 仅非 SourceBroken/Palette 错误,指数退避 2s/4s,retryCount ≤ 2)。
/// 启动恢复:[start()] 扫描仓储 pending(queued/running)→ 重置 queued 重排队。
/// 完成流程:任务落终态 + 输出路径 → 生成 [ExportHistory] 快照入库 → 事件流通知。
///
/// 取消:[cancel] 经 [CancellationManager] 标记令牌(引擎侧终止进程)并幂等清理。
/// 并发度 [concurrency] 可注入(测试注入 1 验证单槽语义)。
class TaskManager {
  TaskManager({
    required TaskRepository taskRepository,
    required HistoryRepository historyRepository,
    required FFmpegService ffmpegService,
    required PlatformAdapter platformAdapter,
    required AppLogger logger,
    Future<void> Function(Duration)? retryDelay,
    this.concurrency = kConcurrency,
  }) : _taskRepository = taskRepository,
       _historyRepository = historyRepository,
       _ffmpegService = ffmpegService,
       _platformAdapter = platformAdapter,
       _logger = logger,
       _retryDelay = retryDelay ?? Future<void>.delayed;

  /// 默认并发槽数(§8.3.7:P6 提至 2)。
  static const kConcurrency = 2;

  final TaskRepository _taskRepository;
  final HistoryRepository _historyRepository;
  final FFmpegService _ffmpegService;
  final PlatformAdapter _platformAdapter;
  final AppLogger _logger;
  final Future<void> Function(Duration) _retryDelay;

  /// 并发槽数(可注入)。
  final int concurrency;

  static const kMaxRetryCount = 2;

  final List<int> _queue = [];
  final Set<int> _running = {};
  final Map<int, VideoInfo> _videos = {};
  final Map<int, CancelToken> _tokens = {};
  final Map<int, CancellationManager> _cancelManagers = {};
  bool _started = false;
  final Map<int, DateTime> _lastProgressWrite = {};
  bool _pumping = false;

  final _progressController = StreamController<TaskProgress>.broadcast();
  final _taskEvents = StreamController<ExportTask>.broadcast();

  /// 实时进度流(UI 消费,外部可再节流)。
  Stream<TaskProgress> get progressStream => _progressController.stream;

  /// 任务状态变化流(queued→running→终态,UI 列表与完成弹窗消费)。
  Stream<ExportTask> get taskEvents => _taskEvents.stream;

  /// 当前全部任务(按 id 序)。
  Future<List<ExportTask>> get tasks => _taskRepository.all();

  /// 提交转换任务(FIFO 入队;若空闲立即启动)。
  ///
  /// [setting.end] 缺省时装配为 [video.duration](公共 API 自洽,直连不产生
  /// `-to 00:00:00.000` 空窗口)。
  /// [outputDir] 非空时输出到用户目录(意图路径写回任务,重试/恢复沿用);
  /// 缺省保持系统临时目录行为。
  Future<int> submit(
    GifSetting setting,
    VideoInfo video, {
    String? outputDir,
  }) async {
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
    if (outputDir != null && outputDir.isNotEmpty) {
      final outputPath = resolveOutputPath(
        outputDir: outputDir,
        sourcePath: video.path,
        taskId: id,
      );
      await _update(
        ExportTask(
          id: id,
          videoPath: task.videoPath,
          outputPath: outputPath,
          settings: effective,
          state: TaskState.queued,
          createdAt: task.createdAt,
        ),
      );
    }
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

  /// 取消全部非终态任务(运行中令牌 + 排队直接终态;P6-WP2)。
  Future<void> cancelAll() async {
    final ids = <int>{..._running, ..._queue};
    for (final id in ids) {
      await cancel(id);
    }
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

  /// 填充空闲并发槽(双槽:while 循环一次拉起 ≤ 并发度个任务)。
  ///
  /// 循环体全程同步无 await,正常路径不可能重入;[_pumping] 为防御性守卫。
  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_running.length < concurrency && _queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        _running.add(id);
        unawaited(_run(id)); // 不再 await:双槽并行
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(int id) async {
    try {
      // 统一守卫:任务缺失或已被取消(取消-启动竞态)→ 直接退出,
      // finally 释放槽位并补位
      final task = await _taskRepository.byId(id);
      if (task == null || task.state != TaskState.queued) return;
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
      // 用户目录输出(提交时意图路径)或临时目录缺省
      final outputPath = task.outputPath ?? '$workDir/out.gif';
      final token = CancelToken();
      _tokens[id] = token;
      // 取消清理条件化:仅清理工作目录内临时文件,用户目录输出不删
      // (半成品保留且文件名含 taskId 不覆盖)
      final cancelFiles = ['$workDir/palette.png'];
      if (outputPath.startsWith(workDir)) {
        cancelFiles.add(outputPath);
      }
      _cancelManagers[id] = CancellationManager(
        token: token,
        tempFiles: cancelFiles,
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
            // Isar 化后避免每帧持久化;per-task 节流(双槽互不干扰)
            final now = DateTime.now();
            final last = _lastProgressWrite[id];
            if (last == null ||
                now.difference(last) >= const Duration(milliseconds: 500)) {
              _lastProgressWrite[id] = now;
              unawaited(
                _update(
                  current.copyWith(
                    state: TaskState.running,
                    progress: p.percent,
                  ),
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
        try {
          await _historyRepository.add(history);
        } catch (e, st) {
          // 历史入库失败不影响任务完成(输出已生成),仅记录日志
          _logger.e('历史快照入库失败: id=$id', error: e, stackTrace: st);
        }
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
            task.retryCount < kMaxRetryCount) {
          final retryCount = task.retryCount + 1;
          await _update(
            current.copyWith(
              state: TaskState.queued,
              retryCount: retryCount,
              errorCode: e.errorCode,
            ),
          );
          _logger.w('任务退避重试: id=$id retry=$retryCount code=${e.errorCode}');
          _emitTask(current);
          // 退避期间不重新入队(任务仍在 _running 占槽,任何 _pump 都不会
          // 再启动它,防双启动);退避结束重读状态,期间被取消则不入队
          await _retryDelay(Duration(seconds: 2 * retryCount));
          final latest = await _taskRepository.byId(id);
          if (latest != null && latest.state == TaskState.queued) {
            _queue.add(id);
          }
          return; // 不再 await _pump:由 finally 先释放槽位再 pump
        }
        // errorDetail 存用户可读文案(userMessage)而非 toString:
        // 后者含绝对路径/类名,违反 §5.4"UI 不泄露原始路径"
        final errorCode = e is DomainException ? e.errorCode : 'GIF_UNKNOWN';
        final errorDetail = _truncate(
          e is DomainException ? e.userMessage : '转换失败,请重试',
        );
        await _finish(
          id,
          TaskState.failed,
          errorCode: errorCode,
          errorDetail: errorDetail,
        );
      }
    } finally {
      // 统一出口:释放槽位后再 pump(顺序即协议,防重试/并发下双启动)
      _tokens.remove(id);
      _cancelManagers.remove(id);
      _running.remove(id);
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

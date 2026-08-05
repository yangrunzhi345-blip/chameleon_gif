import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart' show visibleForTesting;

import '../../../core/logger/app_logger.dart';
import '../../../domain/entities/export_history.dart';
import '../../../domain/entities/export_task.dart';
import '../../../domain/entities/image_gif_source.dart';
import '../../../domain/entities/video_info.dart';
import '../../../domain/exceptions/domain_exception.dart';
import '../../../domain/exceptions/encode_exception.dart';
import '../../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../../domain/repository_interfaces/ffmpeg_service.dart';
import '../../../domain/repository_interfaces/history_repository.dart';
import '../../../domain/repository_interfaces/task_repository.dart';
import '../../../domain/value_objects/gif_setting.dart';
import '../../../domain/value_objects/task_progress.dart';
import '../../../domain/value_objects/task_state.dart';
import '../../../shared/platform/gallery_save_result.dart';
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

  /// 图片模式源缓存(与 [_videos] 平行:submitFromImages 提交时缓存,
  /// _run 消费;恢复路径以 task.imagePaths 兜底重建)。
  final Map<int, ImageGifSource> _imageSources = {};

  final Map<int, CancelToken> _tokens = {};
  final Map<int, CancellationManager> _cancelManagers = {};

  /// 取消请求集合(P7 修复):cancel() 进入即**同步**登记,消除 byId await
  /// 窗口——"cancel 与 _run 启动交错时,取消被吞、任务最终完成"的竞态
  /// (集成测试 full_chain 偶发暴露);_run 在 byId 后与 token 登记后各
  /// 检查一次,未启动即取消。
  final Set<int> _cancelRequests = {};
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
    // 广播落库实体(真实 id),杜绝 id=0 幽灵事件
    await _emitTask(await _taskRepository.byId(id) ?? task);
    unawaited(_pump());
    return id;
  }

  /// 提交图片合成任务(多图 → GIF,与 [submit] 同构)。
  ///
  /// [setting.end] 缺省时装配为总输出时长 `N × 每图时长`(进度分母自洽);
  /// 图片路径列表随任务持久化([ExportTask.imagePaths]),崩溃恢复/重转
  /// 以此为源重建,不依赖 ffprobe。
  Future<int> submitFromImages(
    GifSetting setting,
    ImageGifSource source, {
    String? outputDir,
  }) async {
    final total = source.totalDuration(setting);
    final effective = setting.end == null
        ? setting.copyWith(end: total)
        : setting;
    final task = ExportTask(
      id: 0,
      videoPath: source.paths.first,
      imagePaths: source.paths,
      settings: effective,
      state: TaskState.queued,
      createdAt: DateTime.now(),
    );
    final id = await _taskRepository.add(task);
    if (outputDir != null && outputDir.isNotEmpty) {
      final outputPath = resolveOutputPath(
        outputDir: outputDir,
        sourcePath: source.paths.first,
        taskId: id,
      );
      await _update(
        ExportTask(
          id: id,
          videoPath: task.videoPath,
          imagePaths: source.paths,
          outputPath: outputPath,
          settings: effective,
          state: TaskState.queued,
          createdAt: task.createdAt,
        ),
      );
    }
    _imageSources[id] = source;
    _queue.add(id);
    _logger.i('任务入队: id=$id images=${source.paths.length}张');
    await _emitTask(await _taskRepository.byId(id) ?? task);
    unawaited(_pump());
    return id;
  }

  /// 取消任务:queued 直接终态;running/启动窗口经 [CancellationManager]
  /// 触发令牌(引擎终止)+ 幂等清理,状态由转换侧或本方法收尾。
  ///
  /// 竞态守卫(P6-WP3):[_run] 标记 running 前存在 await 窗口,期间 manager
  /// 已登记但 state 仍是 queued;此处不再要求 state==running,manager 存在
  /// 即取消,未 running 时补落 cancelled 终态,防"取消被吞、任务最终完成"。
  Future<void> cancel(int id) async {
    // 同步登记取消意图:与 _run 的检查点(byId 后/token 登记后)配对,
    // 消除"取消被吞、任务最终完成"的启动窗口竞态(P7 集成测试暴露)
    _cancelRequests.add(id);
    try {
      final task = await _taskRepository.byId(id);
      if (task == null || task.state.isFinal) return; // 终态幂等
      final manager = _cancelManagers[id];
      if (manager != null) {
        await manager.cancel(); // 幂等:标记令牌 + 清理临时文件
        if (task.state != TaskState.running) {
          // 启动窗口/退避期:转换尚未开始,本方法直接落终态
          _queue.remove(id);
          await _update(
            task.copyWith(
              state: TaskState.cancelled,
              finishedAt: DateTime.now(),
            ),
          );
          _emitTask(task);
        }
        return; // running 由转换侧检测令牌后走 cancelled 收尾
      }
      // 排队/启动窗口:若转换已登记令牌(恰在启动),标记之,转换侧检测取消
      _tokens[id]?.cancel();
      _queue.remove(id);
      _videos.remove(id); // 未执行的排队任务,释放提交时缓存的元数据
      _imageSources.remove(id);
      await _update(
        task.copyWith(state: TaskState.cancelled, finishedAt: DateTime.now()),
      );
      _emitTask(task);
    } finally {
      _cancelRequests.remove(id);
    }
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
    // 重排队清理陈旧错误字段(与 start() 恢复路径一致);copyWith 传 null
    // 是"保持"语义无法置空,显式构造
    await _update(
      ExportTask(
        id: task.id,
        videoPath: task.videoPath,
        imagePaths: task.imagePaths,
        outputPath: task.outputPath,
        settings: task.settings,
        state: TaskState.queued,
        progress: task.progress,
        retryCount: task.retryCount,
        createdAt: task.createdAt,
        // 重排队清理陈旧相册状态(与 errorCode 置空同批)
        galleryStatus: GallerySaveStatus.unsupported,
      ),
    );
    _queue.add(id);
    _logger.i('任务重试入队: id=$id');
    await _emitTask(task);
    unawaited(_pump());
  }

  /// 启动恢复:扫描仓储 pending → 全部重置 queued 重排队(崩溃恢复,§8.3.7)。
  /// 幂等:重复调用不重复入队;恢复顺序按 id 升序(提交 FIFO 序,接口契约)。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final pending = await _taskRepository.pending();
    if (pending.isEmpty) return;
    pending.sort((a, b) => a.id.compareTo(b.id));
    _logger.i('恢复扫描: ${pending.length} 个待恢复任务重新排队');
    for (final task in pending) {
      // 重排队 = 全新执行:错误残留/起止时间清除(copyWith 传 null 是
      // "保持"语义无法置空,故显式构造,见 ExportTask.copyWith 文档)
      await _update(
        ExportTask(
          id: task.id,
          videoPath: task.videoPath,
          imagePaths: task.imagePaths,
          outputPath: task.outputPath,
          settings: task.settings,
          state: TaskState.queued,
          progress: task.progress,
          retryCount: task.retryCount,
          createdAt: task.createdAt,
        ),
      );
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
      // 取消请求同步检查(cancel() 先于本次 byId 完成)→ 未启动即取消
      if (_cancelRequests.contains(id)) {
        await _finish(id, TaskState.cancelled);
        return; // finally 释放槽位
      }
      // 提交时携带的完整 video;重试/恢复路径 _videos 已消费,以 settings 兜底
      // (width 取设置宽度而非 0:保证 scale 滤镜不因兜底缺失而输出原始分辨率;
      // 恢复路径以 settings 兜底,完整元数据提交时已持久化于 Isar)
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
      // 图片模式标记:转换走 convertImages,历史快照用总时长(无 VideoInfo)
      final isImageTask =
          task.imagePaths != null && task.imagePaths!.isNotEmpty;
      final workDir = '${_platformAdapter.systemTempDir}/gifforge_$id';
      // 用户目录输出(提交时意图路径)或临时目录缺省
      final outputPath = task.outputPath ?? '$workDir/out.gif';
      final token = CancelToken();
      _tokens[id] = token;
      // token 登记后同步复查取消请求(cancel 恰在 byId 快照后到达时,
      // 标记令牌让下方守卫/转换循环检测取消)
      if (_cancelRequests.contains(id)) {
        token.cancel();
      }
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
      // 启动窗口竞态守卫:标记 running 前 cancel 已标记令牌([cancel] 不再
      // 要求 running),此处直接落 cancelled,转换不进入执行
      if (token.isCancelled) {
        await _finish(id, TaskState.cancelled);
        return; // finally 释放槽位
      }

      var current = task.copyWith(
        state: TaskState.running,
        startedAt: DateTime.now(),
      );
      await _update(current);
      // 竞态二次检查:running 落库挂起期间取消已标记令牌(启动窗口取消),
      // 不再启动转换,避免无效进程与工作目录已清理引发的异常
      if (token.isCancelled) {
        await _finish(id, TaskState.cancelled);
        return; // finally 释放槽位
      }
      _emitTask(current);
      _logger.i('任务开始执行: id=$id');

      try {
        void onProgress(TaskProgress p) {
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
                current.copyWith(state: TaskState.running, progress: p.percent),
              ),
            );
          }
        }

        final result = isImageTask
            ? await _ffmpegService.convertImages(
                source:
                    _imageSources.remove(id) ??
                    ImageGifSource(paths: task.imagePaths!),
                setting: task.settings,
                taskId: id,
                workDir: workDir,
                outputPath: outputPath,
                cancelToken: token,
                onProgress: onProgress,
              )
            : await _ffmpegService.convert(
                setting: task.settings,
                video: video,
                taskId: id,
                workDir: workDir,
                outputPath: outputPath,
                cancelToken: token,
                onProgress: onProgress,
              );
        if (result.cancelled || token.isCancelled) {
          await _finish(id, TaskState.cancelled);
          return;
        }
        // 成功:清理调色板临时文件(输出 out.gif 保留)
        await _cleanupPalette(workDir);
        // Android 相册自动保存:仅私有目录产物(用户自选输出目录不动),
        // 桌面 unsupported 无操作;保存失败不阻塞任务完成(转换本身成功),
        // 状态随任务事件流转,弹窗展示 saved/failed/unsupported 三态
        var gallery = const GallerySaveResult.unsupported();
        if (outputPath.startsWith('${_platformAdapter.systemTempDir}/')) {
          try {
            gallery = await _platformAdapter.saveToGallery(
              outputPath,
              displayName: galleryDisplayName(task.videoPath),
            );
          } on FileSystemException catch (e) {
            // 完成收尾的 await 窗口内取消可能已清理输出文件 → 保存抛异常;
            // 容错为 unsupported,避免掉进外层 catch 被误判 failed
            _logger.w('相册保存失败(输出可能已被取消清理): id=$id', error: e);
          }
        }
        // 完成收尾前复查取消:转换结束后的 await 窗口(清理/相册保存)内
        // cancel() 可能已标记令牌并清理输出,引擎侧已无法检测;
        // CancellationManager.cancel 先同步标记 token 再清理,令牌单调
        // 不可逆,此处复查必然可见。复查通过后才登记历史与落 completed,
        // 取消的任务不产生历史快照。残余微秒级窗口(复查与落库之间)接受。
        if (token.isCancelled || _cancelRequests.contains(id)) {
          _logger.w('完成收尾前检测到取消: id=$id(输出已被清理,落 cancelled)');
          await _finish(id, TaskState.cancelled);
          return;
        }
        final size = result.outputSizeBytes ?? 0;
        final history = ExportHistory(
          id: 0,
          videoPath: task.videoPath,
          imagePaths: task.imagePaths,
          outputPath: outputPath,
          settings: task.settings,
          durationMs: result.elapsed.inMilliseconds,
          outputSizeBytes: size,
          createdAt: DateTime.now(),
          sourceDurationMs: isImageTask
              ? task.settings.effectiveFrameDuration.inMilliseconds *
                    task.imagePaths!.length
              : video.duration.inMilliseconds,
          outputFrameCount: isImageTask
              ? _estimateImageFrameCount(task.settings, task.imagePaths!.length)
              : _estimateFrameCount(task.settings, video),
        );
        try {
          await _historyRepository.add(history);
        } catch (e, st) {
          // 历史入库失败不影响任务完成(输出已生成),仅记录日志
          _logger.e('历史快照入库失败: id=$id', error: e, stackTrace: st);
        }
        _logger.i('任务完成: id=$id size=$size');
        await _finish(
          id,
          TaskState.completed,
          outputPath: outputPath,
          galleryStatus: gallery.status,
          galleryPath: gallery.displayPath,
          galleryUri: gallery.uri,
          galleryMessage: gallery.message,
        );
      } catch (e, st) {
        _logger.e('任务执行失败: id=$id', error: e, stackTrace: st);
        if (token.isCancelled) {
          await _finish(id, TaskState.cancelled);
          return;
        }
        // 失败清理:调色板/工作目录半成品(复用 CancellationManager 幂等
        // 清理,与取消路径同语义:用户自选目录输出不删);重试时 workDir
        // 由 _run 重建,palette 重新生成,无冲突
        await _cancelManagers[id]?.cleanupTempFiles();
        if (e is DomainException &&
            _isRetryable(e) &&
            task.retryCount < kMaxRetryCount) {
          final retryCount = task.retryCount + 1;
          // 显式构造重排队(与 start()/retry() 一致):copyWith 的
          // null 参数是"保持"语义,无法清除 errorDetail/finishedAt/
          // galleryStatus 等陈旧失败痕迹
          await _update(
            ExportTask(
              id: current.id,
              videoPath: current.videoPath,
              imagePaths: current.imagePaths,
              outputPath: current.outputPath,
              settings: current.settings,
              state: TaskState.queued,
              progress: current.progress,
              retryCount: retryCount,
              errorCode: e.errorCode,
              createdAt: current.createdAt,
              galleryStatus: GallerySaveStatus.unsupported,
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
    GallerySaveStatus? galleryStatus,
    String? galleryPath,
    String? galleryUri,
    String? galleryMessage,
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
        galleryStatus: galleryStatus,
        galleryPath: galleryPath,
        galleryUri: galleryUri,
        galleryMessage: galleryMessage,
      ),
    );
    _emitTask(task);
  }

  /// 相册文件名:源视频名去扩展名 + `.gif`,截断 76 字符(MediaStore
  /// DISPLAY_NAME 长度保护,留 `.gif` 4 字符余量)。
  @visibleForTesting
  static String galleryDisplayName(String videoPath) {
    final name = videoPath.split('/').last;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final truncated = base.length > 76 ? base.substring(0, 76) : base;
    return '$truncated.gif';
  }

  Future<void> _update(ExportTask task) => _taskRepository.update(task);

  /// 完成/失败/取消事件广播(读取更新后的最新任务)。
  Future<void> _emitTask(ExportTask task) async {
    final latest = await _taskRepository.byId(task.id) ?? task;
    _taskEvents.add(latest);
  }

  /// 仅"无特征签名"的编码失败(EncodeException)视为瞬时错误可重试;
  /// 已分类的确定性错误(源缺失/损坏、磁盘满、权限、输出冲突、调色板、
  /// FFmpeg 缺失)重试无意义,直接终态(避免无效退避排空队列)。
  bool _isRetryable(DomainException e) => e is EncodeException;

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

  /// 图片模式输出帧数估算 = fps × N × 每图时长。
  int _estimateImageFrameCount(GifSetting setting, int imageCount) {
    final seconds =
        setting.effectiveFrameDuration.inMicroseconds / 1e6 * imageCount;
    return (setting.fps * seconds).round();
  }

  String _truncate(String s) => s.length > 500 ? '${s.substring(0, 500)}…' : s;
}

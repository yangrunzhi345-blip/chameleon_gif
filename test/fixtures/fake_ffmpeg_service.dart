import 'dart:async';
import 'dart:io';

import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';

/// [FFmpegService] 测试替身(P6-WP2 抽取,4 个测试文件共享)。
///
/// 可控:阻塞指定调用序号([blockNthConvert],确定性构造并发用例)、
/// 错误队列/常错、取消即取消令牌、记录调用与收到的 video/setting。
class FakeFfmpegService implements FFmpegService {
  FakeFfmpegService({
    this.error,
    List<Object> errorQueue = const [],
    this.cancelOnRun = false,
    this.blockFirstConvert = false,
    List<int> blockNthConvert = const [],
    this.writeOutput = true,
  }) : _errorQueue = List.of(errorQueue),
       _blockNth = Set.of(blockNthConvert);

  final Object? error;
  final List<Object> _errorQueue;
  final bool cancelOnRun;
  final bool blockFirstConvert;
  final Set<int> _blockNth;

  /// 是否真实写输出文件(testWidgets fake async 下 IO 挂起,渲染类测试关)。
  final bool writeOutput;

  final convertCalls = <int>[];
  final receivedVideos = <VideoInfo>[];
  final convertImagesCalls = <int>[];
  final receivedSources = <ImageGifSource>[];
  final cancelledAtCall = <int, bool>{};
  GifSetting? lastSetting;
  CancelToken? lastCancelToken;
  final Map<int, Completer<void>> _blockers = {};

  /// 解除阻塞(blockFirstConvert 场景)。
  void unblock() {
    for (final b in _blockers.values) {
      if (!b.isCompleted) b.complete();
    }
    _blockers.clear();
  }

  /// 解除全部阻塞(blockNthConvert 并发场景)。
  void unblockAll() => unblock();

  @override
  Future<ConvertResult> convert({
    required GifSetting setting,
    required VideoInfo video,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    convertCalls.add(taskId);
    receivedVideos.add(video);
    lastSetting = setting;
    lastCancelToken = cancelToken;
    cancelledAtCall[convertCalls.length] = cancelToken?.isCancelled ?? false;
    if (cancelOnRun) cancelToken?.cancel();
    final blocked =
        (blockFirstConvert && convertCalls.length == 1) ||
        _blockNth.contains(convertCalls.length);
    if (blocked) {
      final blocker = Completer<void>();
      _blockers[convertCalls.length] = blocker;
      await blocker.future;
      if (cancelToken?.isCancelled ?? false) {
        return ConvertResult(
          exitCode: -1,
          elapsed: Duration.zero,
          cancelled: true,
        );
      }
    }
    onProgress?.call(
      TaskProgress(
        taskId: taskId,
        percent: 0.5,
        elapsed: const Duration(seconds: 1),
      ),
    );
    if (_errorQueue.isNotEmpty) {
      final e = _errorQueue.removeAt(0);
      throw e;
    }
    if (error != null) throw error!;
    if (writeOutput) {
      // 真实写出输出文件(用户目录输出测试断言存在性)
      await File(outputPath).writeAsBytes(List.filled(123, 1));
    }
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }

  /// 图片路径:与 [convert] 同语义(共享阻塞/错误/取消控制),记录调用与源。
  @override
  Future<ConvertResult> convertImages({
    required ImageGifSource source,
    required GifSetting setting,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    convertImagesCalls.add(taskId);
    receivedSources.add(source);
    return convert(
      setting: setting,
      video: VideoInfo(
        path: source.paths.first,
        formatName: '',
        duration: Duration.zero,
        width: source.width,
        height: source.height,
        codec: '',
      ),
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
    );
  }
}

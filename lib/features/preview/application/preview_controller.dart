import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/video_info.dart';
import '../../../domain/repository_interfaces/player_port.dart';
import '../infrastructure/media_kit_player_port.dart';
import 'preview_state.dart';
import 'throttle_stream.dart';

/// 播放器端口(app 生命周期;测试经 override 注入 FakePlayerPort)。
/// 与控制器同文件定义,避免 providers 与 controller 循环 import。
final previewPlayerPortProvider = Provider<PreviewPlayerPort>(
  (ref) => MediaKitPlayerPort(),
);

/// 预览会话控制器(docs/06-模块设计.md §6.2 M02,docs/09-状态管理.md §9.2)。
///
/// 封装 [PreviewPlayerPort] 生命周期(open→play→pause→seek→dispose)并驱动
/// [PreviewState] 状态机;对外暴露 200ms 节流的 position 流与 duration 流。
///
/// 生命周期纪律(R-06 缓解,见 docs/13-风险分析.md):autoDispose + `ref.onDispose`
/// 内取消订阅并 dispose 播放器,防资源泄漏。
class PreviewController extends Notifier<PreviewState> {
  PreviewPlayerPort? _port;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  bool _disposed = false;

  @override
  PreviewState build() {
    // Riverpod 手动 NotifierProvider 无构造注入,依赖在 build() 内经 watch 获取
    final port = ref.watch(previewPlayerPortProvider);
    _port = port;
    _errorSub = port.errorStream.listen((_) {
      state = PreviewState.error(
        errorCode: 'GIF_PLAY_FAILED',
        errorMessage: '视频播放失败,请尝试其他文件',
        video: state.video,
      );
    });
    _playingSub = port.playingStream.listen(
      (p) => state = state.copyWith(isPlaying: p),
    );
    _completedSub = port.completedStream.listen(
      (c) => state = state.copyWith(isCompleted: c),
    );
    ref.onDispose(() {
      _disposed = true;
      _errorSub?.cancel();
      _playingSub?.cancel();
      _completedSub?.cancel();
      port.dispose();
    });
    return const PreviewState.idle();
  }

  /// 加载并自动播放;异步期间可能被 autoDispose 回收,每个 await 后守卫
  /// [_disposed] 避免写已销毁的 state。
  Future<void> load(VideoInfo video) async {
    state = PreviewState.loading(video);
    try {
      await _port!.open(video.path);
    } catch (e) {
      if (_disposed) return;
      state = PreviewState.error(
        errorCode: 'GIF_PLAY_OPEN_FAILED',
        errorMessage: '视频加载失败,请尝试其他文件',
        video: video,
      );
      return;
    }
    if (!_disposed) {
      state = PreviewState.ready(video, isPlaying: true);
    }
  }

  void play() => _port?.play();

  void pause() => _port?.pause();

  Future<void> seekTo(Duration position) async => _port?.seek(position);

  /// 200ms 节流的播放位置流(UI 进度条/时间轴消费)。
  Stream<Duration> get positionStream {
    final port = _port;
    if (port == null) return const Stream.empty();
    return throttleStream(
      port.positionStream,
      const Duration(milliseconds: 200),
    );
  }

  Stream<Duration> get durationStream =>
      _port?.durationStream ?? const Stream.empty();
}

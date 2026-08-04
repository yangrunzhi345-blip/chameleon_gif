import 'dart:async';

import 'package:gif_forge/domain/repository_interfaces/player_port.dart';

/// [PreviewPlayerPort] 测试替身:可控发射事件、记录调用。
///
/// 真实实现依赖 libmpv FFI(flutter test 环境不可控),widget 测试与单测
/// 一律注入本 Fake(见 preview_player_port 渲染降级分支)。
class FakePlayerPort implements PreviewPlayerPort {
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  String? openedPath;
  var playCount = 0;
  var pauseCount = 0;
  final seekCalls = <Duration>[];
  var disposed = false;

  bool _playing = false;
  bool _completed = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 10);

  /// 非空时 open 抛该错误(测试模拟加载失败)。
  Object? openError;

  /// 打开 [path] 后 emit 事件。
  @override
  Future<void> open(String path) {
    openedPath = path;
    _playing = true;
    emitPlaying(true);
    emitDuration(_duration);
    if (openError != null) {
      return Future.error(openError!);
    }
    return Future.value();
  }

  @override
  void play() {
    playCount++;
    _playing = true;
    emitPlaying(true);
  }

  @override
  void pause() {
    pauseCount++;
    _playing = false;
    emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    _position = position;
    emitPosition(position);
  }

  @override
  Future<void> dispose() async {
    if (disposed) return; // 幂等:流控制器二次 close 抛 StateError
    disposed = true;
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
  }

  // ---- 事件发射(测试驱动用) ----

  void emitPosition(Duration position) {
    _position = position;
    _positionCtrl.add(position);
  }

  void emitDuration(Duration duration) {
    _duration = duration;
    _durationCtrl.add(duration);
  }

  void emitPlaying(bool playing) => _playingCtrl.add(playing);

  void emitCompleted(bool completed) {
    _completed = completed;
    _completedCtrl.add(completed);
  }

  void emitError(String message) => _errorCtrl.add(message);

  @override
  PlayerStateSnapshot get state => PlayerStateSnapshot(
    playing: _playing,
    completed: _completed,
    position: _position,
    duration: _duration,
  );

  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;

  @override
  Stream<Duration> get durationStream => _durationCtrl.stream;

  @override
  Stream<bool> get playingStream => _playingCtrl.stream;

  @override
  Stream<bool> get completedStream => _completedCtrl.stream;

  @override
  Stream<String> get errorStream => _errorCtrl.stream;

  @override
  Object get renderHandle => 'fake-render-handle';
}

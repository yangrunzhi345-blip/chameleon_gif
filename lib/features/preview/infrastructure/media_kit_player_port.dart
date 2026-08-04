import 'package:media_kit/media_kit.dart';

import '../../../domain/repository_interfaces/player_port.dart';

/// [PreviewPlayerPort] 的 media_kit 实现。
///
/// [Player] 是纯 Dart 类(底层 FFI libmpv),media_kit_video 的 `VideoController`
/// 需消费同一 Player 实例(经 [renderHandle] 暴露给 UI 层)。
class MediaKitPlayerPort implements PreviewPlayerPort {
  MediaKitPlayerPort({Player? player}) : _player = player ?? Player();

  final Player _player;
  bool _disposed = false;

  @override
  Object get renderHandle => _player;

  @override
  Future<void> open(String path) {
    // 必须经 Uri.file 编码:用户目录含中文/空格时 file:// 原样拼接会失败
    return _player.open(Media(Uri.file(path).toString()));
  }

  @override
  void play() => _player.play();

  @override
  void pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    if (_disposed) return; // 幂等:media_kit Player.dispose 二次调用必抛断言
    _disposed = true;
    await _player.dispose(); // dispose 内含 stop
  }

  @override
  PlayerStateSnapshot get state {
    final s = _player.state;
    return PlayerStateSnapshot(
      playing: s.playing,
      completed: s.completed,
      position: s.position,
      duration: s.duration,
    );
  }

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<String> get errorStream => _player.stream.error;
}

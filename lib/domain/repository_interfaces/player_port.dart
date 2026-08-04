/// 播放器状态快照(即时读取 + 单测断言用)。
class PlayerStateSnapshot {
  const PlayerStateSnapshot({
    required this.playing,
    required this.completed,
    required this.position,
    required this.duration,
  });

  final bool playing;
  final bool completed;
  final Duration position;
  final Duration duration;
}

/// 预览播放器端口(docs/06-模块设计.md §6.2 M02)。
///
/// 功能层只依赖本端口;真实实现 [MediaKitPlayerPort] 封装 media_kit Player,
/// 测试注入 Fake 即可在纯 Dart 环境驱动状态机。
abstract interface class PreviewPlayerPort {
  /// 打开并自动播放(path 为本地文件路径)。
  Future<void> open(String path);

  void play();

  void pause();

  Future<void> seek(Duration position);

  /// 释放播放器资源(会话结束必须调用,防泄漏,见 docs/13 R-06)。
  Future<void> dispose();

  PlayerStateSnapshot get state;

  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;

  /// UI 桥:presentation 构造播放器组件所需的具体句柄(media_kit Player)。
  /// 类型保持 [Object] 以守住 Domain 零第三方依赖红线;presentation 内单点强转。
  Object get renderHandle;
}

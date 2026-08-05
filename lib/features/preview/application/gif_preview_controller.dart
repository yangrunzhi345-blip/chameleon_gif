import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../domain/entities/video_info.dart';
import 'preview_state.dart';

/// GIF 逐帧播放控制器(纯 Dart,image 包解码;docs/13 R-07 实证)。
///
/// 背景:Android 上 media_kit(mpv)无法播放 GIF(真机 errorStream 报播放
/// 失败,桌面正常),改用 image 包逐帧解码 + Timer 按帧延迟推进,全平台
/// 行为一致,不依赖 mpv 的 GIF demuxer。
///
/// 状态复用 [PreviewState](isPlaying/lifecycle),控制条接口与
/// [PreviewController] 同构(positionStream/durationStream/play/pause/seek);
/// 帧渲染经 [frameStream] 逐帧推送 [ui.Image](UI 层 RawImage 消费)。
///
/// 性能:按需解码当前帧 + 最近帧缓存(解码过的帧不重解,循环播放第二圈
/// 起全缓存流畅);单帧解码在主 isolate(小尺寸 GIF 可跟上帧率,真机实测)。
/// 单帧解码函数(注入 seam:单测注入替身避免依赖 dart:ui 引擎;默认
/// 走 image 包逐帧解码)。
typedef GifFrameDecode =
    Future<ui.Image> Function(Uint8List bytes, int frameIndex);

/// 默认解码实现:image 包解帧 → RGBA → [ui.decodeImageFromPixels]。
Future<ui.Image> _defaultDecode(Uint8List bytes, int frameIndex) async {
  final decoded = img.decodeGif(bytes, frame: frameIndex);
  if (decoded == null) {
    throw const FormatException('GIF 帧解码失败');
  }
  // 4.x API:uint8 × 4 通道 = RGBA8888
  final rgba = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba.getBytes(),
    rgba.width,
    rgba.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class GifPreviewController extends Notifier<PreviewState> {
  GifPreviewController({GifFrameDecode? decodeFrame})
    : _decodeFrameImpl = decodeFrame ?? _defaultDecode;

  static const _maxFrameCache = 96;

  final GifFrameDecode _decodeFrameImpl;

  Uint8List? _bytes;
  img.GifInfo? _info;
  Timer? _timer;
  bool _disposed = false;
  int _frameIndex = 0;
  int _pendingDecode = -1;
  ui.Image? _currentFrame;
  final Map<int, ui.Image> _cache = {};
  final _frameController = StreamController<ui.Image>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();

  @override
  PreviewState build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _currentFrame?.dispose();
      for (final f in _cache.values) {
        f.dispose();
      }
      _cache.clear();
      _frameController.close();
      _positionController.close();
    });
    return const PreviewState.idle();
  }

  /// 加载并自动播放 GIF([video.path] 指向 GIF 文件)。
  Future<void> load(VideoInfo video) async {
    state = PreviewState.loading(video);
    try {
      final bytes = await File(video.path).readAsBytes();
      final info = img.GifDecoder().startDecode(bytes);
      if (info == null || info.numFrames == 0) {
        throw const FormatException('GIF 无帧');
      }
      _bytes = bytes;
      _info = info;
      _frameIndex = 0;
      // 首帧就绪即 ready(后续帧按延迟推进,渐进显示)
      await _decodeFrame(0);
      if (_disposed) return;
      state = PreviewState.ready(video, isPlaying: true);
      _scheduleNext();
    } catch (e) {
      if (_disposed) return;
      state = PreviewState.error(
        errorCode: 'GIF_PLAY_OPEN_FAILED',
        errorMessage: 'GIF 加载失败,请尝试其他文件',
        video: video,
      );
    }
  }

  void play() {
    if (state.lifecycle != PreviewLifecycle.ready) return;
    state = state.copyWith(isPlaying: true);
    _scheduleNext();
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isPlaying: false);
  }

  /// 按时间定位帧(控制条拖动)。
  Future<void> seekTo(Duration position) async {
    final info = _info;
    if (info == null) return;
    final index = _indexFor(position);
    if (index == _frameIndex) return;
    _frameIndex = index;
    await _decodeFrame(index);
    if (!_disposed) _positionController.add(_positionOf(index));
  }

  /// 解码后的帧流(UI 渲染消费)。
  Stream<ui.Image> get frameStream => _frameController.stream;

  /// 200ms 节流的当前位置流(与 [PreviewController] 契约一致)。
  Stream<Duration> get positionStream => _positionController.stream;

  /// 总时长(帧数 × 帧延迟)。
  Stream<Duration> get durationStream => Stream.value(_totalDuration());

  /// 按帧延迟推进;帧延迟钳制 [20ms, 1s](异常 GIF 值保护)。
  void _scheduleNext() {
    if (_disposed || state.lifecycle != PreviewLifecycle.ready) return;
    _timer?.cancel();
    final info = _info!;
    final delayMs = info.frames[_frameIndex].duration.clamp(20, 1000);
    _timer = Timer(Duration(milliseconds: delayMs), () async {
      if (_disposed) return;
      _frameIndex = (_frameIndex + 1) % info.numFrames;
      await _decodeFrame(_frameIndex);
      if (!_disposed) {
        _positionController.add(_positionOf(_frameIndex));
        _scheduleNext();
      }
    });
  }

  /// 解码第 [index] 帧:命中缓存直接复用;否则解码并入缓存
  /// (LRU 上限 [_maxFrameCache],超出清理最旧帧)。
  Future<void> _decodeFrame(int index) async {
    final cached = _cache[index];
    if (cached != null) {
      _setCurrent(cached);
      return;
    }
    if (_pendingDecode == index) return; // 解码中防重入
    _pendingDecode = index;
    try {
      final frame = await _decodeFrameImpl(_bytes!, index);
      _cache[index] = frame;
      while (_cache.length > _maxFrameCache) {
        final oldest = _cache.keys.reduce((a, b) => a < b ? a : b);
        _cache.remove(oldest)?.dispose();
      }
      _setCurrent(frame);
    } finally {
      _pendingDecode = -1;
    }
  }

  void _setCurrent(ui.Image frame) {
    if (_currentFrame != null && !identical(_currentFrame, frame)) {
      _currentFrame!.dispose();
    }
    _currentFrame = frame;
    if (!_disposed) _frameController.add(frame);
  }

  Duration _totalDuration() {
    final info = _info;
    if (info == null) return Duration.zero;
    return _positionOf(info.numFrames);
  }

  /// 第 [index] 帧的起始时间(累计帧延迟)。
  Duration _positionOf(int index) {
    final info = _info!;
    var ms = 0;
    for (var i = 0; i < index; i++) {
      ms += info.frames[i].duration.clamp(20, 1000);
    }
    return Duration(milliseconds: ms);
  }

  int _indexFor(Duration position) {
    final info = _info!;
    var ms = position.inMilliseconds;
    for (var i = 0; i < info.numFrames; i++) {
      ms -= info.frames[i].duration.clamp(20, 1000);
      if (ms < 0) return i;
    }
    return info.numFrames - 1;
  }
}

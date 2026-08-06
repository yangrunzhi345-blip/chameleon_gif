/// 相机采集 ffmpeg 命令装配纯函数(仿 GifCommandBuilder,可快照单测)。
///
/// 契约(docs/18 §4.1;快照锁定):
/// - Linux v4l2:`-input_format mjpeg` 恒定(UVC 压缩流,避免 YUYV
///   原始流带宽爆炸);`-video_size` 仅双边分辨率齐全时注入;
/// - Windows dshow:设备名整串传入 `video="<名>"`(Process.start 直传
///   无 shell,ffmpeg 自解析引号,禁止外部拼接);
/// - 统一:`-t` 前置输入限时(进程到时自退,exit 0)+ `-y` 显式
///   (防 tmp 残留时 ffmpeg 因 stdin 非 tty 直接 abort)。
library;

import '../../../core/utils/duration_format.dart';
import '../../../domain/value_objects/capture_params.dart';

/// 相机采集输入类型。
enum CameraInputKind {
  /// Linux `/dev/videoN`。
  v4l2,

  /// Windows dshow 设备名。
  dshow,
}

/// 相机采集命令装配(输出 Process.start 参数数组,不经 shell)。
class CameraCommandBuilder {
  const CameraCommandBuilder();

  /// 预览流参数(与录制/推流共用):
  /// - libx264 编码(实时预览低延迟,preset veryfast);
  /// - 强制关键帧(x264 GOP 30 帧=2s@15fps + 表达式定时关键帧):
  ///   播放器中途接入/录制切换时 2s 内恢复画面(实测必要);
  /// - mpegts 封装走 UDP(单播,本地回环,低延迟)。
  static const previewCodecArgs = [
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-g',
    '30',
    '-keyint_min',
    '30',
    '-sc_threshold',
    '0',
    '-force_key_frames',
    'expr:gte(t,n_forced*2)',
    '-pix_fmt',
    'yuv420p',
  ];

  /// 预览命令(纯 UDP 推流,不落文件;盲拍 → 实时预览,docs/18 里程碑 4)。
  ///
  /// [previewUrl] 形如 `udp://127.0.0.1:PORT?pkt_size=1316`(Process.start
  /// 直传,`?` 无需转义);命令恒运行(无 -t,由端口层生命周期控制)。
  List<String> buildPreview({
    required CaptureParams params,
    required CameraInputKind kind,
    required String input,
    required String previewUrl,
  }) {
    final fps = _formatFps(params.fps);
    final videoSize = _videoSize(params);
    switch (kind) {
      case CameraInputKind.v4l2:
        return [
          '-f',
          'v4l2',
          '-input_format',
          'mjpeg',
          ...videoSize,
          '-framerate',
          fps,
          '-i',
          input,
          '-an',
          ...previewCodecArgs,
          '-f',
          'mpegts',
          previewUrl,
        ];
      case CameraInputKind.dshow:
        return [
          '-f',
          'dshow',
          '-framerate',
          fps,
          ...videoSize,
          '-i',
          'video="$input"',
          '-an',
          ...previewCodecArgs,
          '-f',
          'mpegts',
          previewUrl,
        ];
    }
  }

  /// 录制命令(预览开启时):同一编码流**双 muxer** —— mp4 文件 +
  /// UDP 预览流(单编码器双输出,CPU 友好;实测方案)。
  ///
  /// 录制参数与 [build] 同语义(`-t` 输入侧限时 + `-y` 显式),另加
  /// 强制关键帧保证录制中播放器持续恢复画面。
  List<String> buildWithPreview({
    required CaptureParams params,
    required CameraInputKind kind,
    required String input,
    required String outputPath,
    required String previewUrl,
  }) {
    final fps = _formatFps(params.fps);
    final limit = formatFfmpegTime(
      Duration(milliseconds: params.maxDurationMs),
    );
    final videoSize = _videoSize(params);
    switch (kind) {
      case CameraInputKind.v4l2:
        return [
          '-f',
          'v4l2',
          '-input_format',
          'mjpeg',
          ...videoSize,
          '-framerate',
          fps,
          '-i',
          input,
          '-an',
          ...previewCodecArgs,
          '-t',
          limit,
          '-map',
          '0:v',
          '-f',
          'mp4',
          '-y',
          outputPath,
          '-map',
          '0:v',
          '-f',
          'mpegts',
          previewUrl,
        ];
      case CameraInputKind.dshow:
        return [
          '-f',
          'dshow',
          '-framerate',
          fps,
          ...videoSize,
          '-i',
          'video="$input"',
          '-an',
          ...previewCodecArgs,
          '-t',
          limit,
          '-map',
          '0:v',
          '-f',
          'mp4',
          '-y',
          outputPath,
          '-map',
          '0:v',
          '-f',
          'mpegts',
          previewUrl,
        ];
    }
  }

  /// 装配命令。
  ///
  /// [input]:v4l2 = 设备节点(/dev/videoN);dshow = 设备名(命令内
  /// 自动包 `video="<名>"` 引号)。
  List<String> build({
    required CaptureParams params,
    required CameraInputKind kind,
    required String input,
    required String outputPath,
  }) {
    final fps = _formatFps(params.fps);
    final limit = formatFfmpegTime(
      Duration(milliseconds: params.maxDurationMs),
    );
    final videoSize = _videoSize(params);

    switch (kind) {
      case CameraInputKind.v4l2:
        return [
          '-f',
          'v4l2',
          '-input_format',
          'mjpeg',
          ...videoSize,
          '-framerate',
          fps,
          '-t',
          limit,
          '-i',
          input,
          '-pix_fmt',
          'yuv420p',
          '-y',
          outputPath,
        ];
      case CameraInputKind.dshow:
        return [
          '-f',
          'dshow',
          '-framerate',
          fps,
          ...videoSize,
          '-t',
          limit,
          '-i',
          'video="$input"',
          '-pix_fmt',
          'yuv420p',
          '-y',
          outputPath,
        ];
    }
  }

  /// 分辨率参数(双边齐全才注入 `-video_size`;单边/缺省 → 设备默认)。
  static List<String> _videoSize(CaptureParams params) {
    final hasResolution =
        params.resolutionWidth != null && params.resolutionHeight != null;
    return hasResolution
        ? [
            '-video_size',
            '${params.resolutionWidth}x${params.resolutionHeight}',
          ]
        : const <String>[];
  }

  /// 帧率格式化为 ffmpeg 参数(整数不带小数,如 '15')。
  static String _formatFps(double fps) {
    return fps % 1 == 0 ? fps.toStringAsFixed(0) : fps.toString();
  }
}

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
    final hasResolution =
        params.resolutionWidth != null && params.resolutionHeight != null;
    final videoSize = hasResolution
        ? [
            '-video_size',
            '${params.resolutionWidth}x${params.resolutionHeight}',
          ]
        : <String>[];

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

  /// 帧率格式化为 ffmpeg 参数(整数不带小数,如 '15')。
  static String _formatFps(double fps) {
    return fps % 1 == 0 ? fps.toStringAsFixed(0) : fps.toString();
  }
}

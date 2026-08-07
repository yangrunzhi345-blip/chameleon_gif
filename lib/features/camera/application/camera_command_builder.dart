/// 相机采集 ffmpeg 命令装配纯函数(仿 GifCommandBuilder,可快照单测)。
///
/// 契约(docs/18 §4.1;快照锁定):
/// - Linux v4l2:`-input_format mjpeg` 恒定(UVC 压缩流,避免 YUYV
///   原始流带宽爆炸);`-video_size` 仅双边分辨率齐全时注入;
/// - Windows dshow:设备名整串传入 `video="<名>"`(Process.start 直传
///   无 shell,ffmpeg 自解析引号,禁止外部拼接);
/// - 统一:`-t` 前置输入限时(进程到时自退,exit 0;0 = 不限时长
///   则省略,与 RecordCommandBuilder 同语义)+ `-y` 显式
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

  /// 预览命令(截帧管道,docs/18 里程碑 4;方案 C 实测定案)。
  ///
  /// media_kit 的 libmpv 播放实时流(FIFO/http/UDP)存在库级缺陷
  /// (No video or audio streams selected,已实测闭环),故预览改用
  /// ffmpeg 周期性抓帧:`-vf fps=15` 输出独立 JPEG 帧
  /// (`-f image2pipe -vcodec mjpeg pipe:1`),Dart 侧按 SOI/EOI 切帧
  /// 经 Image.memory 渲染。命令恒运行(无 -t,生命周期归端口层)。
  ///
  /// 帧率 15fps + 中等分辨率(scale 960 宽)+ 高质量 JPEG:
  /// - 2fps 实测观感严重卡顿(幻灯片感),15fps 画面流畅;
  /// - 480 宽放大填满窗口时马赛克/模糊,960 接近窗口宽度无明显放大;
  /// - `-q:v 3` 高质量 JPEG(默认压缩块状伪影明显,实测马赛克)。
  static const previewFrameRate = 15.0;
  static const previewScale = 960;
  static const previewJpegQuality = 3;

  List<String> buildPreview({
    required CaptureParams params,
    required CameraInputKind kind,
    required String input,
  }) {
    final fps = _formatFps(params.fps);
    final videoSize = _videoSize(params);
    final vf = 'fps=${_formatFps(previewFrameRate)},scale=$previewScale:-2';
    const jpegQuality = ['-q:v', '$previewJpegQuality'];
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
          '-vf',
          vf,
          '-f',
          'image2pipe',
          '-vcodec',
          'mjpeg',
          ...jpegQuality,
          'pipe:1',
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
          '-vf',
          vf,
          '-f',
          'image2pipe',
          '-vcodec',
          'mjpeg',
          ...jpegQuality,
          'pipe:1',
        ];
    }
  }

  /// 录制命令(预览激活时):单采集**双编码器双输出** —— mp4 文件 +
  /// 预览 JPEG 帧管道(录中实时预览:录制进程持续输出帧流,绕开
  /// media_kit 流播放缺陷,实测方案)。
  ///
  /// 录制参数与 [build] 同语义(`-t` 输入侧限时);预览输出滤镜
  /// `fps=15,scale=960:-2` + `-q:v 3` 与 [buildPreview] 同构,UI 侧
  /// 帧分割/渲染逻辑完全复用。
  List<String> buildWithPreview({
    required CaptureParams params,
    required CameraInputKind kind,
    required String input,
    required String outputPath,
  }) {
    final fps = _formatFps(params.fps);
    final limit = _durationLimit(params);
    final videoSize = _videoSize(params);
    final previewVf =
        'fps=${_formatFps(previewFrameRate)},scale=$previewScale:-2';
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
          if (limit != null) ...['-t', limit],
          '-i',
          input,
          '-an',
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-map',
          '0:v',
          '-f',
          'mp4',
          '-y',
          outputPath,
          '-map',
          '0:v',
          '-vf',
          previewVf,
          '-c:v',
          'mjpeg',
          '-q:v',
          '$previewJpegQuality',
          '-f',
          'image2pipe',
          'pipe:1',
        ];
      case CameraInputKind.dshow:
        return [
          '-f',
          'dshow',
          '-framerate',
          fps,
          ...videoSize,
          if (limit != null) ...['-t', limit],
          '-i',
          'video="$input"',
          '-an',
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-map',
          '0:v',
          '-f',
          'mp4',
          '-y',
          outputPath,
          '-map',
          '0:v',
          '-vf',
          previewVf,
          '-c:v',
          'mjpeg',
          '-q:v',
          '$previewJpegQuality',
          '-f',
          'image2pipe',
          'pipe:1',
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
    final limit = _durationLimit(params);
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
          if (limit != null) ...['-t', limit],
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
          if (limit != null) ...['-t', limit],
          '-i',
          'video="$input"',
          '-pix_fmt',
          'yuv420p',
          '-y',
          outputPath,
        ];
    }
  }

  /// 时长上限(毫秒;0 = 不限,不加 `-t`,录制终止仅靠端口层手动停止/
  /// 取消;与 RecordCommandBuilder 同语义)。
  static String? _durationLimit(CaptureParams params) {
    return params.maxDurationMs > 0
        ? formatFfmpegTime(Duration(milliseconds: params.maxDurationMs))
        : null;
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

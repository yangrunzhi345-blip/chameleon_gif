/// 桌面录屏命令装配纯函数(仿 GifCommandBuilder,可快照单测)。
///
/// 分支契约(docs/19 §3.3;快照锁定,禁止改动参数顺序/语义):
/// - x11grab(Linux X11):`-t` 前置输入限时 + `-i <DISPLAY>(+x+y)`;
/// - wfRecorder(Linux Wayland):wlr-screencopy 直接抓屏,无 -t(进程
///   常驻,由端口层停止/超时终止;SIGTERM 正常封口,实测定案);
/// - gdigrab(Windows):全屏/自定义区域/窗口(窗口模式 UI 延后,builder 支持)。
/// ffmpeg 分支统一尾链 `-an -pix_fmt yuv420p -y <out>`(屏幕 RGB →
/// H.264 兼容像素格式;`-an` 显式防意外协商音频轨,锁定确定性)。
library;

import '../../../core/utils/duration_format.dart';
import '../../../domain/value_objects/record_params.dart';

/// 桌面录屏采集方式(builder 输入分支)。
enum RecordCommandKind { x11grab, wfRecorder, gdigrab }

/// 录屏命令装配(输出 `-progress` 剥离的 Process.start 参数数组,
/// 不经 shell;设备名/窗口标题含空格由 ffmpeg 自解析)。
class RecordCommandBuilder {
  const RecordCommandBuilder();

  /// 装配命令。
  ///
  /// [display] 仅 [RecordCommandKind.x11grab] 使用(如 ':1');其余分支忽略。
  List<String> build({
    required RecordParams params,
    required RecordCommandKind kind,
    String? display,
    required String outputPath,
  }) {
    final fps = _formatFps(params.fps);
    final limit = formatFfmpegTime(
      Duration(milliseconds: params.maxDurationMs),
    );
    const suffix = ['-an', '-pix_fmt', 'yuv420p', '-y'];
    final tail = [...suffix, outputPath];

    switch (kind) {
      case RecordCommandKind.x11grab:
        final dpy = display;
        assert(dpy != null && dpy.isNotEmpty, 'x11grab 需要 DISPLAY 值');
        final isCustom =
            params.regionMode == RecordRegion.custom &&
            params.regionWidth != null &&
            params.regionHeight != null;
        return [
          '-f',
          'x11grab',
          '-framerate',
          fps,
          if (isCustom) ...[
            '-video_size',
            '${params.regionWidth}x${params.regionHeight}',
          ],
          '-draw_mouse',
          params.drawCursor ? '1' : '0',
          '-t',
          limit,
          '-i',
          isCustom
              ? '$dpy+${params.regionX ?? 0}+${params.regionY ?? 0}'
              : dpy!,
          ...tail,
        ];
      case RecordCommandKind.wfRecorder:
        // Wayland(wlr-screencopy):-r 帧率、-g 区域(全屏省略)、
        // -f 输出文件;无 -t(进程常驻,由端口层停止/超时终止);
        // 光标恒带(无开关,wf-recorder 0.6 无 cursor 选项)
        final isCustom =
            params.regionMode == RecordRegion.custom &&
            params.regionWidth != null &&
            params.regionHeight != null;
        return [
          '-r',
          fps,
          if (isCustom) ...[
            '-g',
            '${params.regionWidth}x${params.regionHeight}'
                '+${params.regionX ?? 0}+${params.regionY ?? 0}',
          ],
          '-f',
          outputPath,
        ];
      case RecordCommandKind.gdigrab:
        final isCustom =
            params.regionMode == RecordRegion.custom &&
            params.regionWidth != null &&
            params.regionHeight != null;
        final isWindow =
            params.regionMode == RecordRegion.window &&
            params.windowTitle != null;
        return [
          '-f',
          'gdigrab',
          '-framerate',
          fps,
          if (isCustom) ...[
            '-offset_x',
            '${params.regionX ?? 0}',
            '-offset_y',
            '${params.regionY ?? 0}',
            '-video_size',
            '${params.regionWidth}x${params.regionHeight}',
          ],
          '-t',
          limit,
          '-i',
          isWindow ? 'title=${params.windowTitle}' : 'desktop',
          ...tail,
        ];
    }
  }

  /// 帧率格式化为 ffmpeg 参数(整数不带小数,如 '15';小数保留,如 '15.5')。
  static String _formatFps(double fps) {
    return fps % 1 == 0 ? fps.toStringAsFixed(0) : fps.toString();
  }
}

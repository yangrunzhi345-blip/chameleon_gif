import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/screen_recorder_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import '../application/record_environment_detector.dart';

/// 桌面录屏实现(系统 ffmpeg 采集,docs/19 里程碑 2/3)。
///
/// 采集方式按环境选型:Windows `-f gdigrab`(恒可用);Linux X11
/// `-f x11grab`;Linux Wayland `-f pipewire`(ffmpeg 6.1+,依赖
/// xdg-desktop-portal 授权弹窗)。与桌面转码同型:Process 执行 +
/// [CancelToken] 取消。产物落位复用 CaptureCommitter(仅素材目录,
/// 无相册语义)。
class FfmpegScreenRecorder implements ScreenRecorderPort {
  FfmpegScreenRecorder({
    required this.capturesDir,
    required this.tempDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
    Future<bool> Function(String device)? ffmpegHasDevice,
  }) : _logger = logger,
       _ffmpegHasDevice = ffmpegHasDevice ?? _runFfmpegHasDevice;

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`)。
  final Directory capturesDir;

  /// 私有 tmp 目录(录制中产物,落位后清理)。
  final Directory tempDir;

  // ignore: unused_field -- WP7 落地(录制执行)后使用并移除
  final AppLogger _logger;
  final Future<bool> Function(String device) _ffmpegHasDevice;

  /// 环境探测(可注入测试):Windows 恒 gdigrab;Linux 读会话环境变量。
  RecordEnvironment get _environment {
    if (Platform.isWindows) {
      return const RecordEnvironment(method: RecordCaptureMethod.gdigrab);
    }
    final env = Platform.environment;
    return detectRecordEnvironment(
      sessionType: env['XDG_SESSION_TYPE'],
      display: env['DISPLAY'],
    );
  }

  /// 轻探测:ffmpeg -devices 是否包含指定采集输入(毫秒级,不阻塞入口;
  /// 不做带超时的采集探测 —— portal 存在时该探测会弹系统共享选择框,
  /// 交互副作用不可接受)。
  static Future<bool> _runFfmpegHasDevice(String device) async {
    try {
      final result = await Process.run('ffmpeg', ['-hide_banner', '-devices']);
      return result.exitCode == 0 && result.stdout.toString().contains(device);
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<List<RecordTarget>> enumerateTargets() async {
    // MVP 全屏单目标(窗口枚举延后,依赖 Windows 原生代码)
    return const [RecordTarget(id: '0', title: '全屏')];
  }

  @override
  Future<RecordCapabilities> queryCapabilities() async {
    final env = _environment;
    switch (env.method) {
      case RecordCaptureMethod.x11grab:
        return await _ffmpegHasDevice('x11grab')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.x11grab,
                supportsRegions: true,
                supportsCursorToggle: true,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.x11grab,
                hint: '系统 ffmpeg 缺少 x11grab 输入,请安装完整版 ffmpeg',
              );
      case RecordCaptureMethod.pipewire:
        return await _ffmpegHasDevice('pipewire')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.pipewire,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.pipewire,
                hint:
                    '当前 Wayland 会话缺少屏幕共享支持:系统 ffmpeg 未编译 '
                    'pipewire 输入。请安装支持 pipewire 的 ffmpeg 与 '
                    'xdg-desktop-portal,或切换到 X11 会话',
              );
      case RecordCaptureMethod.gdigrab:
        return await _ffmpegHasDevice('gdigrab')
            ? const RecordCapabilities(
                captureMethod: RecordCaptureMethod.gdigrab,
                supportsRegions: true,
              )
            : const RecordCapabilities(
                screenCaptureAvailable: false,
                captureMethod: RecordCaptureMethod.gdigrab,
                hint: '系统 ffmpeg 缺少 gdigrab 输入,请安装完整版 ffmpeg',
              );
      case RecordCaptureMethod.none:
        return const RecordCapabilities(
          screenCaptureAvailable: false,
          hint: '未检测到可用的录屏环境',
        );
    }
  }

  @override
  Future<CaptureResult> record({
    required RecordParams params,
    CancelToken? cancelToken,
  }) async {
    // WP7 落地:record_command_builder 装配 + CaptureProcessRunner 执行
    throw const CaptureException(
      errorCode: 'GIF_RECORD_UNAVAILABLE',
      userMessage: '桌面录屏暂未开放',
    );
  }

  @override
  Future<void> requestStop() async {
    // WP7 落地:终止当前采集进程(保存)
  }
}

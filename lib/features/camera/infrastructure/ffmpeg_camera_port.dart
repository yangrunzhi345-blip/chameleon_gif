import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import '../application/v4l2_device_parser.dart';

/// 桌面相机拍摄实现(ffmpeg 采集 + v4l2-ctl 控制,docs/18 里程碑 2/3)。
///
/// 采集:Linux `-f v4l2` / Windows `-f dshow`(系统 ffmpeg 二进制,与桌面
/// 转码 ProcessEngine 同型);控制:Linux v4l2-ctl(第二档,能力探测驱动),
/// Windows 第一版不设(无 COM 插件,仅基础档)。
/// 盲拍:无实时取景([previewSupported]=false),录完在工作台回放确认
/// (docs/18 D4)。
class FfmpegCameraPort implements CameraPort {
  FfmpegCameraPort({
    required this.capturesDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
  }) : _adapter = adapter,
       _logger = logger;

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`;CaptureCommitter 使用)。
  final Directory capturesDir;

  // ignore: unused_field -- WP5 落地(CaptureCommitter 落位)后使用并移除
  final PlatformAdapter _adapter;
  final AppLogger _logger;

  @override
  bool get previewSupported => false; // 桌面盲拍

  @override
  Future<List<CameraDevice>> enumerateDevices() async {
    if (Platform.isWindows) {
      // dshow:ffmpeg -sources dshow 枚举(零 COM;设备名即输入标识)
      final names = await _runFfmpegSourcesDshow();
      return [for (final name in names) CameraDevice(id: name, name: name)];
    }
    // Linux:优先 v4l2-ctl(--list-devices + get-fmt-video 探活过滤 meta
    // 节点,实测同一摄像头双节点 /dev/video0+1);v4l2-ctl 缺失降级
    // ffmpeg -sources v4l2(不区分 meta,采集失败由错误映射兜底)
    final entries = await _enumerateV4l2();
    return [
      for (final e in entries)
        CameraDevice(id: e.node, name: '${e.name} (${e.node})'),
    ];
  }

  /// v4l2-ctl 主路径 + ffmpeg -sources 降级路径。
  Future<List<V4l2DeviceEntry>> _enumerateV4l2() async {
    try {
      final result = await Process.run('v4l2-ctl', ['--list-devices']);
      if (result.exitCode == 0 &&
          result.stdout.toString().contains('/dev/video')) {
        final entries = parseV4l2ListDevices(result.stdout.toString());
        if (entries.isNotEmpty) {
          final alive = <V4l2DeviceEntry>[];
          for (final e in entries) {
            final probe = await Process.run('v4l2-ctl', [
              '-d',
              e.node,
              '--get-fmt-video',
            ]);
            if (probe.exitCode == 0) alive.add(e);
          }
          if (alive.isNotEmpty) return alive;
        }
      }
    } on ProcessException catch (e, st) {
      _logger.w('v4l2-ctl 枚举失败(降级 ffmpeg -sources)', error: e, stackTrace: st);
    }
    try {
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-sources',
        'v4l2',
      ]);
      if (result.exitCode == 0) {
        final entries = parseFfmpegSourcesV4l2(result.stdout.toString());
        if (entries.isNotEmpty) return entries;
      }
    } on ProcessException catch (e, st) {
      _logger.w('ffmpeg -sources v4l2 枚举失败', error: e, stackTrace: st);
    }
    return const [];
  }

  /// Windows dshow 设备枚举(ffmpeg -sources dshow;解析失败返回空)。
  Future<List<String>> _runFfmpegSourcesDshow() async {
    try {
      final result = await Process.run('ffmpeg', [
        '-hide_banner',
        '-sources',
        'dshow',
      ]);
      if (result.exitCode != 0) return const [];
      return parseFfmpegSourcesDshow(result.stdout.toString());
    } on ProcessException catch (e, st) {
      _logger.w('ffmpeg -sources dshow 枚举失败', error: e, stackTrace: st);
      return const [];
    }
  }

  @override
  Future<CameraCapabilities> queryCapabilities(String deviceId) async {
    // WP6 落地:v4l2-ctl -l 控制项 + --list-formats-ext 分辨率/帧率解析
    return const CameraCapabilities();
  }

  @override
  Future<void> applyParams(CaptureParams params) async {
    // WP6 落地:v4l2-ctl --set-ctrl 批量应用第二档控制项
  }

  @override
  Future<CaptureResult> capture({
    required CaptureParams params,
    CancelToken? cancelToken,
  }) async {
    // WP5 落地:CaptureProcessRunner 执行 ffmpeg 采集 + CaptureCommitter 落位
    throw const CaptureException(
      errorCode: 'GIF_CAPTURE_UNAVAILABLE',
      userMessage: '桌面相机采集暂未开放',
    );
  }

  @override
  Future<void> requestStop() async {
    // WP5 落地:终止当前采集进程(保存)
  }
}

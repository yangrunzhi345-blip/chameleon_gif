import 'dart:io';

import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/capture_paths.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/screen_recorder_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/camera/infrastructure/capture_committer.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'screen_record_channel.dart';

/// Android 录屏实现(自写 MediaProjection 原生桥,docs/19 S1-WP2)。
///
/// record 阻塞式:通道 startRecording(Result 挂起)等待结束;超时由原生
/// Timer 自动停(保存);取消经 [cancelToken] → cancelRecording(删 tmp)。
/// 产物落位复用 [CaptureCommitter](素材目录持久副本 + 相册展示副本)。
class ScreenRecorderPortImpl implements ScreenRecorderPort {
  ScreenRecorderPortImpl({
    required this.capturesDir,
    required this.tempDir,
    required PlatformAdapter adapter,
    required AppLogger logger,
    ScreenRecordChannel? channel,
  }) : _logger = logger,
       _channel = channel ?? ScreenRecordChannel(),
       _committer = CaptureCommitter(
         adapter: adapter,
         capturesDir: capturesDir,
       );

  /// 素材落位目录(`<docsDir>/chameleon_gif/captures`,阶段 B 决策 3)。
  final Directory capturesDir;

  /// 私有 tmp 目录(app cache;录制中产物,落位后清理)。
  final Directory tempDir;

  final AppLogger _logger;
  final ScreenRecordChannel _channel;
  final CaptureCommitter _committer;

  @override
  /// 手动停止当前录制(保存;录制中由页面停止按钮调用,经原生通道)。
  Future<void> requestStop() async {
    await _channel.stopRecording();
  }

  @override
  Future<List<RecordTarget>> enumerateTargets() async {
    // Android 恒全屏(虚拟显示比例经 params.aspectRatio;窗口/区域属桌面)
    return const [RecordTarget(id: '0', title: '全屏')];
  }

  @override
  Future<RecordCapabilities> queryCapabilities() async {
    // Android MediaProjection 恒可用(授权在录制页内引导);
    // 每次录制需系统授权(Android 14 起强制,UI 文案据此渲染)
    return const RecordCapabilities(
      screenCaptureAvailable: true,
      requiresSystemConsent: true,
    );
  }

  @override
  Future<CaptureResult> record({
    required RecordParams params,
    CancelToken? cancelToken,
  }) async {
    final fileName = buildCaptureFilename(DateTime.now());
    final tmpPath = '${tempDir.path}/$fileName';
    // 取消协商:页面返回/取消 → 原生取消(删 tmp,回复 cancelled)
    cancelToken?.onCancel(() => _channel.cancelRecording());

    final raw = await _channel.startRecording(
      fps: params.fps,
      maxDurationMs: params.maxDurationMs,
      aspectRatio: params.aspectRatio,
      outputPath: tmpPath,
    );
    switch (raw?['status']) {
      case 'saved':
        _logger.i('录屏完成: ${raw?['path']} ${raw?['durationMs']}ms');
        return await _committer.commit(
          tmpPath: raw?['path'] as String? ?? tmpPath,
          fileName: fileName,
          durationMs: raw?['durationMs'] as int? ?? 0,
        );
      case 'rejected':
        throw const CapturePermissionDeniedException(
          userMessage: '未获得录屏授权,已取消录制',
        );
      case 'cancelled':
        await _committer.discardTmp(tmpPath);
        throw const CaptureCancelledException();
      default:
        await _committer.discardTmp(tmpPath);
        throw CaptureException(
          errorCode: 'GIF_RECORD_ERROR',
          userMessage: raw?['message'] as String? ?? '录制失败,请重试',
        );
    }
  }
}

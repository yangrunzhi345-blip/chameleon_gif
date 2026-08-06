import 'package:flutter/services.dart';

/// 录屏通道桥(原生侧 ScreenRecordChannel.kt,仿 AndroidMediaStoreSaver)。
///
/// [startRecording] 的 MethodChannel.Result 原生侧**挂起**至录制结束
/// (手动停止/超时/取消/授权拒绝),返回统一 Map:
/// `{status: saved, path, durationMs} / {status: rejected} /
///  {status: cancelled} / {status: error, message}`。
/// 桌面等无原生实现宿主抛 MissingPluginException。
class ScreenRecordChannel {
  const ScreenRecordChannel({this.channel = const MethodChannel(_channelName)});

  static const _channelName = 'com.chameleongif.chameleon_gif/screen_record';

  final MethodChannel channel;

  /// 开始录制并等待结束(Result 挂起;见类注释返回契约)。
  Future<Map<dynamic, dynamic>?> startRecording({
    required double fps,
    required int maxDurationMs,
    double? aspectRatio,
    required String outputPath,
  }) async {
    return await channel.invokeMethod<Map<dynamic, dynamic>>('startRecording', {
      'fps': fps,
      'maxDurationMs': maxDurationMs,
      'aspectRatio': aspectRatio,
      'outputPath': outputPath,
    });
  }

  /// 手动停止(正常保存)。
  Future<void> stopRecording() async {
    await channel.invokeMethod<void>('stopRecording');
  }

  /// 取消录制(删 tmp;页面返回/取消时调用,防前台服务泄漏)。
  Future<void> cancelRecording() async {
    await channel.invokeMethod<void>('cancelRecording');
  }
}

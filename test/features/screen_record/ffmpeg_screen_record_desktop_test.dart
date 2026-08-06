import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/ffmpeg_screen_recorder.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面录屏**本机真实实测**(真实 ffmpeg + 真实显示环境)。
///
/// 依赖运行时环境:本机为 Wayland(niri)+ 无 pipewire 输入,故真实
/// x11grab 验证须以 X11 环境变量注入运行:
/// `XDG_SESSION_TYPE= DISPLAY=:1 flutter test test/features/screen_record/
/// ffmpeg_screen_record_desktop_test.dart`(XWayland 亦可抓取)。
/// 普通运行(wayland 环境)→ 能力探测断言置灰分支,录制分支跳过。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('record_real_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  FfmpegScreenRecorder buildRecorder() => FfmpegScreenRecorder(
    capturesDir: capturesDir,
    tempDir: Directory('${tempRoot.path}/tmp'),
    adapter: PlatformAdapter(),
    logger: AppLogger(),
  );

  test('本机实测:能力探测(wayland → pipewire 分支可用性判定)', () async {
    final recorder = buildRecorder();
    final caps = await recorder.queryCapabilities();
    expect(caps.captureMethod, isA<RecordCaptureMethod>());
    // wayland + 无 pipewire demuxer → 置灰 + 指引(本机现状)
    if (caps.captureMethod == RecordCaptureMethod.pipewire) {
      expect(
        caps.screenCaptureAvailable,
        isFalse,
        reason: '本机 ffmpeg 无 pipewire',
      );
      expect(caps.hint, isNotEmpty);
    }
  });

  test('本机实测:x11grab 真实录制 2s → 落位 + ffprobe 可解析', () async {
    final env = Platform.environment;
    if (env['XDG_SESSION_TYPE'] != null || env['DISPLAY'] == null) {
      markTestSkipped(
        '需以 X11 环境运行(XDG_SESSION_TYPE= DISPLAY=:1 flutter test ...)',
      );
      return;
    }
    final recorder = buildRecorder();
    final caps = await recorder.queryCapabilities();
    expect(caps.captureMethod, RecordCaptureMethod.x11grab, reason: 'X11 分支');
    expect(caps.screenCaptureAvailable, isTrue);

    final result = await recorder.record(
      params: const RecordParams(maxDurationMs: 2000, fps: 15),
      cancelToken: null,
    );
    expect(File(result.finalPath).existsSync(), isTrue, reason: '产物落位');
    final probe = Process.runSync('ffprobe', [
      '-v',
      'error',
      '-show_format',
      result.finalPath,
    ]);
    expect(probe.exitCode, 0, reason: 'ffprobe 可解析产物');
    final duration = RegExp(
      r'duration=([\d.]+)',
    ).firstMatch(probe.stdout.toString());
    expect(duration, isNotNull, reason: '含时长元数据');
    expect(double.parse(duration!.group(1)!), inInclusiveRange(1.0, 4.0));
  });
}

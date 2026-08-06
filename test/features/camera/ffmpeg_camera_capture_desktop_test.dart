import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/core/utils/duration_format.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/shared/platform/process_ffprobe_executor.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

/// 桌面相机拍摄**本机真实实测**(真实 ffmpeg + 真实摄像头;无设备跳过)。
///
/// 注意:真实拍摄用例集中在**同一文件** —— flutter test 跨文件并发,
/// 摄像头为独占资源,分文件会争抢(busy)。
/// 覆盖:超时自退落位 / 取消清理 / 产物 ffprobe 可解析 /
/// 端到端(拍摄 → 解析 → 两遍调色板 → GIF)。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('cam_real_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  bool hasCamera() {
    try {
      final result = Process.runSync('v4l2-ctl', ['--list-devices']);
      return result.exitCode == 0 &&
          result.stdout.toString().contains('/dev/video');
    } on ProcessException {
      return false;
    }
  }

  FfmpegCameraPort buildPort() => FfmpegCameraPort(
    capturesDir: capturesDir,
    adapter: PlatformAdapter(),
    logger: AppLogger(),
  );

  test('本机实测:超时自退(-t 2s)→ 落位,ffprobe 可解析,时长约 2s', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    final result = await port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        maxDurationMs: 2000,
        fps: 15,
      ),
      cancelToken: null,
    );
    expect(File(result.finalPath).existsSync(), isTrue, reason: '产物落位');
    expect(result.durationMs, inInclusiveRange(1500, 5000), reason: '-t 到时自退');

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
    final seconds = double.parse(duration!.group(1)!);
    expect(seconds, inInclusiveRange(1.5, 4.0), reason: '实际时长约 2s');
  });

  test('本机实测:录制中取消 → 半成品清理,素材目录无残留', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    final token = CancelToken();
    final future = port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        maxDurationMs: 30000,
        fps: 15,
      ),
      cancelToken: token,
    );
    // 等待进程启动(会话就绪),再取消
    await Future<void>.delayed(const Duration(milliseconds: 800));
    token.cancel();
    await expectLater(future, throwsA(isA<CaptureCancelledException>()));
    expect(
      capturesDir.existsSync() ? capturesDir.listSync() : const [],
      isEmpty,
      reason: '取消不落位',
    );
  });

  test('本机实测:端到端(拍摄 → ffprobe 解析 → 两遍调色板 → GIF89a)', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    final shot = await port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        maxDurationMs: 2000,
        fps: 15,
      ),
      cancelToken: null,
    );
    expect(File(shot.finalPath).existsSync(), isTrue, reason: '拍摄产物落位');

    // ffprobe 解析(复用桌面解析链路)
    final probe = await const ProcessFfprobeExecutor().run(shot.finalPath);
    expect(probe.exitCode, 0, reason: 'ffprobe 解析成功');
    expect(probe.probeJson, isNotEmpty, reason: '可解析出元数据');

    // 两遍调色板导出(与转换链路同命令语义)
    final palette = '${tempRoot.path}/palette.png';
    final gif = '${tempRoot.path}/out.gif';
    final limit = formatFfmpegTime(const Duration(seconds: 2));
    final pass1 = await Process.run('ffmpeg', [
      '-ss',
      '0',
      '-t',
      limit,
      '-i',
      shot.finalPath,
      '-vf',
      'fps=15,scale=480:-1:flags=lanczos,palettegen',
      '-y',
      palette,
    ]);
    expect(pass1.exitCode, 0, reason: 'palettegen 成功');
    final pass2 = await Process.run('ffmpeg', [
      '-ss',
      '0',
      '-t',
      limit,
      '-i',
      shot.finalPath,
      '-i',
      palette,
      '-lavfi',
      'fps=15,scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse',
      '-y',
      gif,
    ]);
    expect(pass2.exitCode, 0, reason: 'paletteuse 成功');
    final gifFile = File(gif);
    expect(gifFile.existsSync(), isTrue);
    expect(gifFile.lengthSync(), greaterThan(1024), reason: 'GIF 非空产物');
    final header = gifFile.readAsBytesSync().sublist(0, 6);
    expect(String.fromCharCodes(header), 'GIF89a', reason: 'GIF 文件头有效');
  });

  test('本机实测:预览出帧 → 录制中帧流持续(双输出)→ 产物有效 → 恢复接续', () async {
    if (!hasCamera()) {
      markTestSkipped('本机无摄像头');
      return;
    }
    final port = buildPort();
    // 1. 截帧预览:帧流收到真实 JPEG 帧(15fps,等 2s)
    final frames = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(frames, isNotNull, reason: '帧流就绪');
    final received = <Uint8List>[];
    final sub = frames!.listen(received.add);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(received, isNotEmpty, reason: '预览帧流收到真实帧');
    final first = received.first;
    expect(first.length, greaterThan(100), reason: '真实 JPEG 帧非空');
    expect(first[0], 0xFF);
    expect(first[1], 0xD8, reason: 'SOI 标记');
    expect(first[first.length - 2], 0xFF);
    expect(first[first.length - 1], 0xD9, reason: 'EOI 标记');
    final framesBeforeRecord = received.length;
    expect(framesBeforeRecord, greaterThan(5), reason: '15fps 2s 出帧充足');

    // 2. 真实录制 3s(双输出:文件 + 预览帧管道,帧流持续)
    final result = await port.capture(
      params: const CaptureParams(
        deviceId: '/dev/video0',
        fps: 15,
        maxDurationMs: 3000,
      ),
      cancelToken: null,
    );
    expect(File(result.finalPath).existsSync(), isTrue, reason: '产物落位');
    final probe = Process.runSync('ffprobe', [
      '-v',
      'error',
      '-show_format',
      result.finalPath,
    ]);
    expect(probe.exitCode, 0, reason: '产物可解析');
    expect(
      received.length,
      greaterThan(framesBeforeRecord),
      reason: '录制中帧流持续输出(实时预览)',
    );
    final framesAfterRecord = received.length;

    // 3. 恢复预览(同一帧流接续),继续出帧
    final restored = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(restored, isNotNull, reason: '恢复预览');
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(
      received.length,
      greaterThan(framesAfterRecord),
      reason: '恢复后帧流接续输出',
    );
    await sub.cancel();

    // 4. 清理
    await port.stopPreview();
    final afterStop = Process.runSync('pgrep', ['-x', 'ffmpeg']);
    expect(afterStop.exitCode, isNot(0), reason: '预览进程已停止');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

import '../../shared/platform/capture_process_runner_test.dart'
    show FakeProcess;

/// 预览会话管理集成测试(注入 FakeProcess 驱动的 runner):
/// 启动/幂等/录制集成(双 muxer)/取消恢复/停止。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;
  late List<String> lastArgs;
  late List<FakeProcess> processes;
  late List<List<String>> commands;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('preview_');
    capturesDir = Directory('${tempRoot.path}/captures');
    processes = [];
    commands = [];
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  /// 假 runner:预览进程(无 -t)常驻由 stop/取消终止;
  /// 录制进程(含 -t)按 [recordExitCode] 退出(0 = 模拟 -t 自退;
  /// null = 常驻供取消)。
  CaptureProcessRunner fakeRunner({int? recordExitCode}) =>
      CaptureProcessRunner(
        startProcess: (exe, args) async {
          lastArgs = args;
          commands.add(args);
          final isRecord = args.contains('-t');
          final process = FakeProcess(
            exitCode: isRecord ? recordExitCode : null,
          );
          processes.add(process);
          if (isRecord) {
            File(args[args.indexOf('-y') + 1]).writeAsStringSync('partial');
          }
          return process;
        },
      );

  FfmpegCameraPort buildPort(CaptureProcessRunner? runner) => FfmpegCameraPort(
    capturesDir: capturesDir,
    adapter: _TempAdapter(tempRoot.path),
    logger: AppLogger(),
    runner: runner ?? fakeRunner(),
  );

  test('startPreview:起推流进程,返回 UDP 地址,命令含 mpegts 尾链', () async {
    final port = buildPort(null);
    final url = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(url, startsWith('udp://127.0.0.1:'));
    expect(url, endsWith('?pkt_size=1316'));
    expect(lastArgs, containsAllInOrder(['-f', 'mpegts', url!]));
    expect(lastArgs, isNot(contains('-t')), reason: '预览恒运行');
    expect(processes, hasLength(1));
  });

  test('startPreview 幂等:同设备同参 → 复用地址,不重复起进程', () async {
    final port = buildPort(null);
    final url1 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    final url2 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(url1, url2);
    expect(processes, hasLength(1), reason: '幂等不重复启动');
  });

  test('设备切换:先停旧预览再起新(不同地址)', () async {
    final port = buildPort(null);
    final url1 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    final url2 = await port.startPreview(
      deviceId: '/dev/video1',
      params: const CaptureParams(fps: 15),
    );
    expect(url2, isNotNull, reason: '新设备可预览');
    expect(url2, isNot(url1), reason: '端口重新分配,地址不同');
    expect(processes, hasLength(2), reason: '新设备新进程');
    expect(processes.first.killSignals, isNotEmpty, reason: '旧预览已停');
  });

  test('capture 集成:预览激活 → 双 muxer 录制 + 结束后恢复预览', () async {
    final port = buildPort(fakeRunner(recordExitCode: 0));
    final url = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(url, isNotNull);

    final result = await port.capture(
      params: const CaptureParams(deviceId: '/dev/video0', fps: 15),
      cancelToken: null,
    );
    // 录制命令(含 -t 的进程)双 muxer:同地址推流
    final recordCmd = commands.firstWhere((c) => c.contains('-t'));
    final mapCount = recordCmd.where((a) => a == '-map').length;
    expect(mapCount, 2, reason: '预览激活时双 muxer');
    expect(recordCmd, containsAllInOrder(['-f', 'mpegts', url!]));
    expect(File(result.finalPath).existsSync(), isTrue);
    // 结束后恢复预览(新进程)
    expect(processes, hasLength(3), reason: '预览+录制+恢复预览');
    final restored = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(restored, url, reason: '恢复后同地址(播放器无需重连)');
    // 幂等:同设备同参再次调用不重建
    final idempotent = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(idempotent, url);
    expect(processes, hasLength(3), reason: '幂等不重复启动');
  });

  test('capture 取消 → 预览恢复', () async {
    final port = buildPort(null);
    final url = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    final token = CancelToken();
    final future = port.capture(
      params: const CaptureParams(deviceId: '/dev/video0', fps: 15),
      cancelToken: token,
    );
    token.cancel();
    await expectLater(future, throwsA(isA<CaptureCancelledException>()));
    // 恢复预览进程
    expect(processes, hasLength(3), reason: '取消后恢复预览');
    expect(url, isNotNull);
  });

  test('未预览时 capture:单文件命令(现状契约不变)', () async {
    final port = buildPort(fakeRunner(recordExitCode: 0));
    final result = await port.capture(
      params: const CaptureParams(deviceId: '/dev/video0', fps: 15),
      cancelToken: null,
    );
    expect(lastArgs.where((a) => a == '-map'), isEmpty, reason: '无预览单文件');
    expect(File(result.finalPath).existsSync(), isTrue);
  });

  test('stopPreview 幂等,预览进程终止', () async {
    final port = buildPort(null);
    await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    await port.stopPreview();
    await port.stopPreview();
    expect(processes.first.killSignals, isNotEmpty, reason: '预览进程已终止');
    final url = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(url, isNotNull, reason: '停止后可重启');
  });
}

class _TempAdapter extends PlatformAdapter {
  _TempAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

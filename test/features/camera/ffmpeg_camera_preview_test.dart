import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/features/camera/infrastructure/ffmpeg_camera_port.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

import '../../shared/platform/capture_process_runner_test.dart'
    show FakeProcess;

/// 预览会话管理集成测试(截帧方案:注入 FakeProcess 输出 JPEG 帧;
/// 覆盖:启动/帧流/幂等/设备切换/录制集成/取消恢复/停止)。
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

  Uint8List jpegFrame(int seed) => Uint8List.fromList([
    0xFF, 0xD8, // SOI
    seed & 0xFF, 0x01, 0x02,
    0xFF, 0xD9, // EOI
  ]);

  /// 假 runner:预览进程(无 -t)与录制进程(含 -t,双输出时)均延迟
  /// 流式输出 JPEG 帧(模拟持续抓帧/录制中预览管道,订阅时序稳定);
  /// 预览常驻由 stop/取消终止,录制按 [recordExitCode] 退出。
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
          // 双输出录制(buildWithPreview)与预览进程均输出帧管道
          final hasPreviewPipe = args.contains('image2pipe');
          if (hasPreviewPipe) {
            Future<void>.delayed(const Duration(milliseconds: 30), () {
              process.emitStdout([...jpegFrame(1), ...jpegFrame(2)]);
            });
            Future<void>.delayed(const Duration(milliseconds: 60), () {
              process.emitStdout([...jpegFrame(3)]);
            });
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

  test('startPreview:起截帧进程,返回 JPEG 帧流,命令含 image2pipe', () async {
    final port = buildPort(null);
    final frames = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(frames, isNotNull, reason: '帧流就绪');
    expect(lastArgs, containsAllInOrder(['-vf', 'fps=15,scale=960:-2']));
    expect(lastArgs, containsAllInOrder(['-f', 'image2pipe', 'pipe:1']));
    expect(lastArgs, isNot(contains('-t')), reason: '预览恒运行');
    expect(processes, hasLength(1));

    // 帧流收到延迟输出的 JPEG 帧(2+1 帧,流式持续)
    final received = <Uint8List>[];
    final sub = frames!.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(received, hasLength(3), reason: '帧流切出完整帧');
    expect(received[0], jpegFrame(1));
  });

  test('startPreview 幂等:同设备同参 → 复用会话,不重复起进程', () async {
    final port = buildPort(null);
    final frames1 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    final frames2 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    // 注:StreamController.stream getter 每次返回新包装对象(底层流
    // 相同),故以"进程不重复启动 + 两流均收到帧"验证幂等
    expect(processes, hasLength(1), reason: '幂等不重复启动');
    final received1 = <Uint8List>[];
    final received2 = <Uint8List>[];
    final sub1 = frames1!.listen(received1.add);
    final sub2 = frames2!.listen(received2.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub1.cancel();
    await sub2.cancel();
    expect(received1, isNotEmpty, reason: '第一流收到帧');
    expect(received2, isNotEmpty, reason: '第二流(同一会话)收到帧');
  });

  test('设备切换:先停旧预览再起新(新帧流)', () async {
    final port = buildPort(null);
    final frames1 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    final frames2 = await port.startPreview(
      deviceId: '/dev/video1',
      params: const CaptureParams(fps: 15),
    );
    expect(frames2, isNotNull, reason: '新设备可预览');
    expect(identical(frames1, frames2), isFalse, reason: '新会话新帧流');
    expect(processes, hasLength(2), reason: '新设备新进程');
    expect(processes.first.killSignals, isNotEmpty, reason: '旧预览已停');
  });

  test('capture 集成:预览激活 → 双输出录制(帧流持续)→ 恢复预览接续', () async {
    final port = buildPort(fakeRunner(recordExitCode: 0));
    final frames1 = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(frames1, isNotNull);
    // 订阅帧流(录制中持续收到帧,实时预览)
    final received = <Uint8List>[];
    final sub = frames1!.listen(received.add);

    final result = await port.capture(
      params: const CaptureParams(deviceId: '/dev/video0', fps: 15),
      cancelToken: null,
    );
    // 录制命令双输出:mp4 文件 + image2pipe 预览管道
    final recordCmd = commands.firstWhere((c) => c.contains('-t'));
    final mapCount = recordCmd.where((a) => a == '-map').length;
    expect(mapCount, 2, reason: '预览激活时双输出(文件+帧管道)');
    expect(recordCmd, containsAllInOrder(['-f', 'image2pipe', 'pipe:1']));
    expect(File(result.finalPath).existsSync(), isTrue);
    // 等录制进程的延迟帧输出(模拟录制中预览管道持续)
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();
    expect(received, isNotEmpty, reason: '帧流录制中持续输出(实时预览)');
    // 结束后恢复预览(新进程,帧流接续)
    expect(processes, hasLength(3), reason: '预览+录制+恢复预览');
    final restored = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(restored, isNotNull);
    // 幂等:同设备同参再次调用不重建(进程数不变)
    final idempotent = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(idempotent, isNotNull);
    expect(processes, hasLength(3), reason: '幂等不重复启动');
    // 恢复会话继续输出帧(接续录制期间的帧流)
    final received2 = <Uint8List>[];
    final sub2 = restored!.listen(received2.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub2.cancel();
    expect(received2, isNotEmpty, reason: '恢复会话输出帧');
  });

  test('capture 取消 → 预览恢复', () async {
    final port = buildPort(null);
    await port.startPreview(
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
    expect(processes, hasLength(3), reason: '取消后恢复预览');
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

  test('stopPreview:帧流关闭 + 进程终止,停止后可重启', () async {
    final port = buildPort(null);
    final frames = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(frames, isNotNull);
    var done = false;
    final sub = frames!.listen((_) {}, onDone: () => done = true);
    await port.stopPreview();
    await port.stopPreview(); // 幂等
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(done, isTrue, reason: '帧流已关闭');
    expect(processes.first.killSignals, isNotEmpty, reason: '预览进程已终止');
    final restarted = await port.startPreview(
      deviceId: '/dev/video0',
      params: const CaptureParams(fps: 15),
    );
    expect(restarted, isNotNull, reason: '停止后可重启');
  });
}

class _TempAdapter extends PlatformAdapter {
  _TempAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

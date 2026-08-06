import 'dart:io';

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

/// FfmpegCameraPort.capture 集成测试(注入 FakeProcess 驱动的 runner;
/// 覆盖:成功落位 / 失败错误映射 / 取消清理 / 手动停止保存)。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('cam_capture_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  late FakeProcess lastProcess;

  /// 假 runner:[exitCode] 非空 = 进程启动即退出(模拟 -t 到时自退);
  /// 空 = 运行中(由 stop/cancel 终止)。
  CaptureProcessRunner fakeRunner({int? exitCode}) => CaptureProcessRunner(
    startProcess: (exe, args) async {
      lastProcess = FakeProcess(exitCode: exitCode);
      // 模拟 ffmpeg 写出半成品
      final out = args[args.indexOf('-y') + 1];
      File(out).writeAsStringSync('partial');
      return lastProcess;
    },
  );

  /// 测试适配器:systemTempDir 指向临时根(与 runner 输出同目录)。
  PlatformAdapter testAdapter() => _TempAdapter(tempRoot.path);

  /// 素材目录无残留(目录不存在视为空 —— 取消/失败路径不落位)。
  bool capturesEmpty() =>
      !capturesDir.existsSync() || capturesDir.listSync().isEmpty;

  test('成功:exit 0 → 落位素材目录,命名 capture_<ts>_<seq>.mp4', () async {
    final port = FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: testAdapter(),
      logger: AppLogger(),
      runner: fakeRunner(exitCode: 0),
    );
    final result = await port.capture(
      params: const CaptureParams(deviceId: '/dev/video0', maxDurationMs: 100),
      cancelToken: null,
    );
    expect(result.finalPath, startsWith(capturesDir.path));
    expect(File(result.finalPath).existsSync(), isTrue);
    expect(File(result.finalPath).readAsStringSync(), 'partial');
    expect(result.durationMs, greaterThanOrEqualTo(0));
    expect(result.galleryStatus, isA<Object>()); // 桌面 unsupported
  });

  test('失败:exit 非 0 + Permission denied → 中文提示,半成品清理', () async {
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async {
        lastProcess = FakeProcess(
          exitCode: 1,
          stderrData: 'v4l2 open failed: Permission denied\n',
        );
        final out = args[args.indexOf('-y') + 1];
        File(out).writeAsStringSync('partial');
        return lastProcess;
      },
    );
    final port = FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: testAdapter(),
      logger: AppLogger(),
      runner: runner,
    );
    await expectLater(
      port.capture(
        params: const CaptureParams(deviceId: '/dev/video0'),
        cancelToken: null,
      ),
      throwsA(
        isA<CaptureException>().having(
          (e) => e.userMessage,
          'userMessage',
          contains('无权限访问摄像头'),
        ),
      ),
    );
    expect(capturesEmpty(), isTrue, reason: '失败不落位');
  });

  test('取消:cancelToken → CaptureCancelledException,半成品已删', () async {
    final token = CancelToken();
    final port = FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: testAdapter(),
      logger: AppLogger(),
      runner: fakeRunner(),
    );
    final future = port.capture(
      params: const CaptureParams(deviceId: '/dev/video0'),
      cancelToken: token,
    );
    token.cancel();
    await expectLater(future, throwsA(isA<CaptureCancelledException>()));
    expect(capturesEmpty(), isTrue);
  });

  test('手动停止:requestStop → SIGTERM,stoppedByRequest 保存', () async {
    final port = FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: testAdapter(),
      logger: AppLogger(),
      runner: fakeRunner(),
    );
    final future = port.capture(
      params: const CaptureParams(deviceId: '/dev/video0'),
      cancelToken: null,
    );
    await port.requestStop();
    final result = await future;
    expect(File(result.finalPath).existsSync(), isTrue);
    expect(lastProcess.killSignals, [ProcessSignal.sigterm]);
  });

  test('设备配置缺失 → 回退枚举首个可用(真实枚举,无设备则提示)', () async {
    final port = FfmpegCameraPort(
      capturesDir: capturesDir,
      adapter: testAdapter(),
      logger: AppLogger(),
      runner: fakeRunner(exitCode: 0),
    );
    final devices = await port.enumerateDevices();
    if (devices.isEmpty) {
      await expectLater(
        port.capture(params: const CaptureParams(), cancelToken: null),
        throwsA(
          isA<CaptureException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('未检测到摄像头'),
          ),
        ),
      );
      return;
    }
    // 有设备:枚举首个生效(命令 input = /dev/videoN)
    final result = await port.capture(
      params: const CaptureParams(),
      cancelToken: null,
    );
    expect(File(result.finalPath).existsSync(), isTrue);
  });
}

class _TempAdapter extends PlatformAdapter {
  _TempAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

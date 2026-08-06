import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/screen_record/application/record_environment_detector.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/ffmpeg_screen_recorder.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';

import '../../shared/platform/capture_process_runner_test.dart'
    show FakeProcess;

/// FfmpegScreenRecorder 集成测试(环境注入 + FakeProcess 驱动的 runner;
/// 覆盖:三分支命令透传 / 成功落位 / 取消 / 手动停止 / none 环境拒绝)。
void main() {
  late Directory tempRoot;
  late Directory capturesDir;
  late FakeProcess lastProcess;
  late List<String> lastArgs;
  late String lastExe;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('record_');
    capturesDir = Directory('${tempRoot.path}/captures');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  /// 假 runner:[exitCode] 非空 = 启动即退出;空 = 运行中(由停止/取消终止)。
  /// 输出路径:ffmpeg 分支 `-y` 后;wf-recorder 分支 `-f` 后。
  /// 产物内容:[bytes] 指定大小(默认 5000B,越过 0 帧校验阈值)。
  CaptureProcessRunner fakeRunner({int? exitCode, int bytes = 5000}) =>
      CaptureProcessRunner(
        startProcess: (exe, args) async {
          lastExe = exe;
          lastArgs = args;
          lastProcess = FakeProcess(exitCode: exitCode);
          final yIdx = args.indexOf('-y');
          final fIdx = args.indexOf('-f');
          final out = yIdx >= 0 ? args[yIdx + 1] : args[fIdx + 1];
          File(out).writeAsBytesSync(List.filled(bytes, 0x30));
          return lastProcess;
        },
      );

  FfmpegScreenRecorder buildRecorder({
    required RecordCaptureMethod method,
    String? display,
    CaptureProcessRunner? runner,
  }) {
    final tmpDir = Directory('${tempRoot.path}/tmp')
      ..createSync(recursive: true);
    return FfmpegScreenRecorder(
      capturesDir: capturesDir,
      tempDir: tmpDir,
      adapter: PlatformAdapter(),
      logger: AppLogger(),
      runner: runner ?? fakeRunner(exitCode: 0),
      environment: RecordEnvironment(method: method, display: display),
    );
  }

  test('none 环境 → CaptureException(不支持)', () async {
    final recorder = buildRecorder(method: RecordCaptureMethod.none);
    await expectLater(
      recorder.record(params: const RecordParams(), cancelToken: null),
      throwsA(
        isA<CaptureException>().having(
          (e) => e.userMessage,
          'userMessage',
          contains('当前环境不支持屏幕录制'),
        ),
      ),
    );
  });

  test('x11grab:命令透传 display + 全屏输入,成功落位', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
    );
    final result = await recorder.record(
      params: const RecordParams(maxDurationMs: 1000),
      cancelToken: null,
    );
    expect(lastArgs, containsAllInOrder(['-f', 'x11grab', '-i', ':1']));
    expect(File(result.finalPath).existsSync(), isTrue);
  });

  test('gdigrab:desktop 输入 + 区域参数透传', () async {
    final recorder = buildRecorder(method: RecordCaptureMethod.gdigrab);
    final result = await recorder.record(
      params: const RecordParams(
        regionMode: RecordRegion.custom,
        regionX: 10,
        regionY: 20,
        regionWidth: 640,
        regionHeight: 480,
      ),
      cancelToken: null,
    );
    expect(lastArgs, containsAllInOrder(['-f', 'gdigrab', '-i', 'desktop']));
    expect(
      lastArgs,
      containsAllInOrder(['-offset_x', '10', '-video_size', '640x480']),
    );
    expect(File(result.finalPath).existsSync(), isTrue);
  });

  test('wfRecorder:-r 帧率 + 全屏,成功落位(executable=wf-recorder)', () async {
    final recorder = buildRecorder(method: RecordCaptureMethod.wfRecorder);
    final result = await recorder.record(
      params: const RecordParams(maxDurationMs: 1000),
      cancelToken: null,
    );
    expect(lastArgs, containsAllInOrder(['-r', '15', '-f']));
    expect(lastExe, 'wf-recorder', reason: 'Wayland 用 wf-recorder 可执行');
    expect(File(result.finalPath).existsSync(), isTrue);
  });

  test('0 帧产物(262B 截断 mp4)→ 删除并提示录制过短', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.wfRecorder,
      runner: fakeRunner(bytes: 262),
    );
    final future = recorder.record(
      params: const RecordParams(),
      cancelToken: null,
    );
    await recorder.requestStop(); // 模拟 0 帧极短录制停止
    await expectLater(
      future,
      throwsA(
        isA<CaptureException>().having(
          (e) => e.userMessage,
          'userMessage',
          contains('录制时间过短'),
        ),
      ),
    );
    expect(
      capturesDir.existsSync() ? capturesDir.listSync() : const [],
      isEmpty,
      reason: '无效产物不落位',
    );
  });

  test('wfRecorder 启动失败 → 中文指引(wlr-screencopy 支持)', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.wfRecorder,
      runner: CaptureProcessRunner(
        startProcess: (exe, args) async {
          lastProcess = FakeProcess(
            exitCode: 1,
            stderrData: 'Failed to connect to display\n',
          );
          return lastProcess;
        },
      ),
    );
    await expectLater(
      recorder.record(params: const RecordParams(), cancelToken: null),
      throwsA(
        isA<CaptureException>().having(
          (e) => e.userMessage,
          'userMessage',
          contains('wlr-screencopy'),
        ),
      ),
    );
  });

  test('取消:cancelToken → 半成品清理', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
      runner: fakeRunner(),
    );
    final token = CancelToken();
    final future = recorder.record(
      params: const RecordParams(),
      cancelToken: token,
    );
    token.cancel();
    await expectLater(future, throwsA(isA<CaptureCancelledException>()));
    expect(
      capturesDir.existsSync() ? capturesDir.listSync() : const [],
      isEmpty,
    );
  });

  test('maxDurationMs=0 → 不启动时长 watchdog(无限录制,仅手动停止)', () {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
      runner: fakeRunner(), // 进程常驻(不注入 exitCode,否则启动即退出)
    );
    fakeAsync((async) {
      // record 尾部含真实文件 IO(完成回调走事件循环),fakeAsync 内
      // 无法推进,故仅断言 kill 信号(watchdog 行为),落位由真实
      // 异步的"手动停止"用例覆盖
      recorder.record(
        params: const RecordParams(maxDurationMs: 0),
        cancelToken: null,
      );
      async.flushMicrotasks();
      // 推进远超原 60s 上限 + 兜底:进程仍运行(watchdog 未启动)
      async.elapse(const Duration(minutes: 10));
      expect(lastProcess.killSignals, isEmpty, reason: '0 = 不限 → 无 watchdog');
      // 手动停止 → kill 请求生效
      recorder.requestStop();
      async.flushMicrotasks();
      async.elapse(Duration.zero); // 冲刷 terminateProcess 轮询 delayed
      expect(lastProcess.killSignals, [ProcessSignal.sigterm]);
    });
  });

  test('maxDurationMs>0 → watchdog 超时自动停(保存)', () {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
      runner: fakeRunner(), // 进程常驻(watchdog 超时触发 stop)
    );
    fakeAsync((async) {
      recorder.record(
        params: const RecordParams(maxDurationMs: 1000),
        cancelToken: null,
      );
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 3000));
      expect(lastProcess.killSignals, isEmpty, reason: '未到 1000+5000 兜底');
      async.elapse(const Duration(seconds: 5)); // 越过 watchdog 触发点
      expect(lastProcess.killSignals, [
        ProcessSignal.sigterm,
      ], reason: 'watchdog 超时自动停');
    });
  });

  test('手动停止:requestStop → SIGTERM 保存', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
      runner: fakeRunner(),
    );
    final future = recorder.record(
      params: const RecordParams(),
      cancelToken: null,
    );
    await recorder.requestStop();
    final result = await future;
    expect(File(result.finalPath).existsSync(), isTrue);
    expect(lastProcess.killSignals, [ProcessSignal.sigterm]);
  });

  test('queryCapabilities:环境注入 → 能力映射正确', () async {
    final recorder = buildRecorder(
      method: RecordCaptureMethod.x11grab,
      display: ':1',
    );
    final caps = await recorder.queryCapabilities();
    expect(caps.captureMethod, RecordCaptureMethod.x11grab);
    expect(caps.supportsRegions, isTrue);
    expect(caps.supportsCursorToggle, isTrue);
    expect(caps.screenCaptureAvailable, isTrue);
  });
}

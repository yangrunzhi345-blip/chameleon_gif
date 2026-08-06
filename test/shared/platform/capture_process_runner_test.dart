import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/shared/platform/capture_process_runner.dart';

/// 可控假进程:kill 时 resolve exitCode(SIGKILL 137 / 其他 255)。
class FakeProcess implements Process {
  FakeProcess({int? exitCode, this.stderrData = '', this.stdoutData = ''}) {
    _stdout.add(utf8.encode(stdoutData));
    _stdout.close();
    _stderr.add(utf8.encode(stderrData));
    _stderr.close();
    if (exitCode != null) _exitCode.complete(exitCode);
  }

  final _exitCode = Completer<int>();
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final String stderrData;
  final String stdoutData;
  final killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 1234;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (!_exitCode.isCompleted) {
      _exitCode.complete(signal == ProcessSignal.sigkill ? 137 : 255);
    }
    return true;
  }
}

/// 采集进程运行器测试(注入 FakeProcess 控制退出/信号/stderr)。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('capture_runner_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('正常结束(exit 0)→ outcome 未停止未取消', () async {
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async => FakeProcess(exitCode: 0),
    );
    final session = await runner.start(
      args: ['-i', 'x'],
      outputPath: '${tempDir.path}/a.mp4',
    );
    final outcome = await session.waitExit();
    expect(outcome.exitCode, 0);
    expect(outcome.stoppedByRequest, isFalse);
    expect(outcome.cancelled, isFalse);
    expect(outcome.elapsed, greaterThanOrEqualTo(Duration.zero));
  });

  test('stop() → SIGTERM,stoppedByRequest=true(保存语义)', () async {
    final process = FakeProcess();
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async => process,
    );
    final session = await runner.start(
      args: ['-i', 'x'],
      outputPath: '${tempDir.path}/b.mp4',
    );
    await session.stop();
    final outcome = await session.waitExit();
    expect(outcome.stoppedByRequest, isTrue);
    expect(process.killSignals, [ProcessSignal.sigterm]);
  });

  test('cancel() → 终止 + 幂等删除半成品', () async {
    final output = File('${tempDir.path}/c.mp4')..writeAsStringSync('partial');
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async => FakeProcess(),
    );
    final session = await runner.start(
      args: ['-i', 'x'],
      outputPath: output.path,
    );
    await session.cancel();
    final outcome = await session.waitExit();
    expect(outcome.cancelled, isTrue);
    expect(output.existsSync(), isFalse, reason: '半成品已删');
    // 重复取消无副作用(幂等)
    await session.cancel();
  });

  test('cancelToken 取消 → 会话标记 cancelled', () async {
    final token = CancelToken();
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async => FakeProcess(),
    );
    final session = await runner.start(
      args: ['-i', 'x'],
      outputPath: '${tempDir.path}/d.mp4',
      cancelToken: token,
    );
    token.cancel();
    final outcome = await session.waitExit();
    expect(outcome.cancelled, isTrue);
  });

  test('stderr 尾部保留 8 行(错误映射依据)', () async {
    final lines = [for (var i = 0; i < 12; i++) 'line$i'];
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async =>
          FakeProcess(exitCode: 1, stderrData: lines.join('\n')),
    );
    final session = await runner.start(
      args: ['-i', 'x'],
      outputPath: '${tempDir.path}/e.mp4',
    );
    await session.waitExit();
    // 流消费异步,冲刷事件循环
    await Future<void>.delayed(Duration.zero);
    expect(session.stderrTail, hasLength(8));
    expect(session.stderrTail.last, 'line11');
    expect(session.stderrTail.first, 'line4');
  });

  test('stdout 与 stderr 行均回调 onLog(诊断日志)', () async {
    final logged = <String>[];
    final runner = CaptureProcessRunner(
      startProcess: (exe, args) async => FakeProcess(
        exitCode: 0,
        stdoutData: 'progress=1\n',
        stderrData: 'stderr-log\n',
      ),
    );
    await runner.start(
      args: ['-i', 'x'],
      outputPath: '${tempDir.path}/f.mp4',
      onLog: logged.add,
    );
    await Future<void>.delayed(Duration.zero);
    expect(logged, ['progress=1', 'stderr-log']);
  });
}

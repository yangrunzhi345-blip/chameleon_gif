import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_minimal/ffmpeg_session_complete_callback.dart';
import 'package:ffmpeg_kit_flutter_minimal/log_callback.dart';
import 'package:ffmpeg_kit_flutter_minimal/return_code.dart';
import 'package:ffmpeg_kit_flutter_minimal/statistics.dart';
import 'package:ffmpeg_kit_flutter_minimal/statistics_callback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/shared/platform/ffmpeg_kit_engine.dart';

/// FFmpegSession 测试替身:仅实现引擎用到的成员,其余 noSuchMethod 兜底
/// (具体类不可在 Linux 实例化,同 ffprobe_kit_executor_test 模式)。
class _FakeSession implements FFmpegSession {
  _FakeSession({this.returnCodeValue = 0});

  final int? returnCodeValue;

  @override
  int getSessionId() => 42;

  @override
  Future<ReturnCode?> getReturnCode() async =>
      returnCodeValue == null ? null : ReturnCode(returnCodeValue!);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake session 未实现: ${invocation.memberName}');
}

/// Statistics 测试替身(implements 抽象类,漏实现走 noSuchMethod)。
class _FakeStatistics implements Statistics {
  _FakeStatistics({
    this.timeUs = 1_500_000,
    this.size = 4096,
    this.speed = 2.5,
  });

  final double timeUs;
  final int size;
  final double speed;

  @override
  double getTime() => timeUs;

  @override
  int getSize() => size;

  @override
  double getSpeed() => speed;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake statistics 未实现: ${invocation.memberName}');
}

/// executeAsync/cancel 的注入替身:记录命令与回调,手动触发 complete/statistics。
class _FakeKit {
  _FakeKit({this.returnCodeValue = 0});

  final int? returnCodeValue;
  String? command;
  FFmpegSessionCompleteCallback? completeCallback;
  LogCallback? logCallback;
  StatisticsCallback? statisticsCallback;
  final cancelCalls = <int?>[];

  Future<FFmpegSession> executeAsync(
    String command, [
    FFmpegSessionCompleteCallback? completeCallback,
    LogCallback? logCallback,
    StatisticsCallback? statisticsCallback,
  ]) async {
    this.command = command;
    this.completeCallback = completeCallback;
    this.logCallback = logCallback;
    this.statisticsCallback = statisticsCallback;
    return _FakeSession(returnCodeValue: returnCodeValue);
  }

  Future<void> cancel([int? sessionId]) async => cancelCalls.add(sessionId);
}

const _request = ConvertRequest(
  command: ['-i', 'a.mp4', '-y', 'out.gif'],
  workDir: '/tmp/work',
  tempFiles: ['/tmp/work/palette.png'],
);

void main() {
  group('FfmpegKitEngine.assembleCommand', () {
    test('空格拼接(Kit 契约,无可执行名前缀:ffmpeg-kit 直接执行 ffmpeg 本体)', () {
      expect(
        FfmpegKitEngine.assembleCommand([
          '-i',
          'a.mp4',
          '-frames:v',
          '1',
          '-y',
          'out.gif',
        ]),
        '-i a.mp4 -frames:v 1 -y out.gif',
      );
    });

    test('空参数列表返回空串', () {
      expect(FfmpegKitEngine.assembleCommand([]), '');
    });

    test('剥离 -progress pipe:1 参数对(ffmpeg-kit 不支持,真机报 Invalid argument)', () {
      expect(
        FfmpegKitEngine.assembleCommand([
          '-ss',
          '00:00:01.000',
          '-i',
          'a.mp4',
          '-progress',
          'pipe:1',
          '-y',
          'out.gif',
        ]),
        '-ss 00:00:01.000 -i a.mp4 -y out.gif',
      );
    });
  });

  group('FfmpegKitEngine.convert', () {
    test('成功路径:命令透传、exitCode/elapsed/cancelled 正确', () async {
      final kit = _FakeKit();
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );

      final future = engine.convert(_request);
      expect(kit.command, '-i a.mp4 -y out.gif', reason: '命令串契约(无 ffmpeg 前缀)');
      kit.completeCallback!(_FakeSession(returnCodeValue: 0));
      final result = await future;

      expect(result.exitCode, 0);
      expect(result.cancelled, isFalse);
      expect(kit.cancelCalls, isEmpty, reason: '成功无取消');
    });

    test('非零退出码透传(上层 ErrorHandler 分类)', () async {
      final kit = _FakeKit(returnCodeValue: 1);
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );

      final future = engine.convert(_request);
      kit.completeCallback!(_FakeSession(returnCodeValue: 1));
      final result = await future;

      expect(result.exitCode, 1);
    });

    test('returnCode 为 null → exitCode -1', () async {
      final kit = _FakeKit(returnCodeValue: null);
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );

      final future = engine.convert(_request);
      kit.completeCallback!(_FakeSession(returnCodeValue: null));
      final result = await future;

      expect(result.exitCode, -1);
    });

    test('取消(执行中):token.cancel → cancel(sessionId)', () async {
      final kit = _FakeKit();
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );
      final token = CancelToken();

      final future = engine.convert(_request, cancelToken: token);
      token.cancel();
      // onCancel 在 executeAsync 完成(会话建立)后才注册,需 flush 微任务
      await pumpEventQueue();

      expect(kit.cancelCalls, [42], reason: '会话建立后取消按 sessionId 终止');
      kit.completeCallback!(_FakeSession());
      final result = await future;
      expect(result.cancelled, isTrue, reason: '完成回调时令牌已取消');
    });

    test('先于会话建立的取消:onCancel 立即执行(竞态覆盖)', () async {
      final kit = _FakeKit();
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );
      final token = CancelToken()..cancel();

      final future = engine.convert(_request, cancelToken: token);
      // token 已取消:onCancel 注册即触发,同样需等会话建立(微任务)
      await pumpEventQueue();

      expect(kit.cancelCalls, [42], reason: 'token 已取消时 onCancel 立即触发');
      kit.completeCallback!(_FakeSession());
      final result = await future;
      expect(result.cancelled, isTrue);
    });

    test('statistics 合成 -progress 风格行喂 onProgress(与桌面解析复用)', () async {
      final kit = _FakeKit();
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );
      final lines = <String>[];

      final future = engine.convert(_request, onProgress: lines.add);
      kit.statisticsCallback!(
        _FakeStatistics(timeUs: 1_500_000, size: 4096, speed: 2.5),
      );
      kit.completeCallback!(_FakeSession());

      await future;
      expect(lines, [
        'out_time_us=1500000',
        'total_size=4096',
        'speed=2.5x',
        'progress=continue',
      ], reason: 'ProgressParser 按行解析,out_time_us 驱动百分比');
    });

    test('statistics time 为小数 → toInt 截断(微秒单位对齐桌面)', () async {
      final kit = _FakeKit();
      final engine = FfmpegKitEngine(
        executeAsync: kit.executeAsync,
        cancel: kit.cancel,
      );
      final lines = <String>[];

      final future = engine.convert(_request, onProgress: lines.add);
      kit.statisticsCallback!(_FakeStatistics(timeUs: 1234567.9));
      kit.completeCallback!(_FakeSession());

      await future;
      expect(lines.first, 'out_time_us=1234567');
    });
  });
}

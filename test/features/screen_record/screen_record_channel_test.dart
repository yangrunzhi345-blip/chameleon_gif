import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/screen_record_channel.dart';

/// [ScreenRecordChannel] 通道契约测试:参数透传、结果解析(挂起 Result)。
///
/// 原生逻辑(MediaProjection/编码)宿主无法测,此处锁定 Dart 侧桥契约;
/// 录制结束各状态(saved/rejected/cancelled/error)由原生异步回复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.chameleongif.chameleon_gif/screen_record');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) => handler(call));
  }

  test('startRecording 参数透传 + saved 结果解析', () async {
    MethodCall? received;
    mock((call) async {
      received = call;
      return {
        'status': 'saved',
        'path': '/tmp/capture_1.mp4',
        'durationMs': 5200,
      };
    });

    final r = await const ScreenRecordChannel().startRecording(
      fps: 15,
      maxDurationMs: 60000,
      aspectRatio: 16 / 9,
      outputPath: '/tmp/capture_1.mp4',
    );
    expect(received?.method, 'startRecording');
    expect(received?.arguments, {
      'fps': 15.0,
      'maxDurationMs': 60000,
      'aspectRatio': 16 / 9,
      'outputPath': '/tmp/capture_1.mp4',
    });
    expect(r?['status'], 'saved');
    expect(r?['durationMs'], 5200);
  });

  test('startRecording 无 aspectRatio → 不传键(全屏原生)', () async {
    MethodCall? received;
    mock((call) async {
      received = call;
      return {'status': 'rejected'};
    });

    await const ScreenRecordChannel().startRecording(
      fps: 15,
      maxDurationMs: 30000,
      outputPath: '/tmp/capture_2.mp4',
    );
    final args = received?.arguments as Map;
    // 键始终存在(原生 call.argument 对 null 返回 null),值为 null 即全屏原生
    expect(args['aspectRatio'], isNull);
  });

  test('rejected/cancelled/error 原样透传', () async {
    mock((call) async => {'status': 'rejected'});
    final r1 = await const ScreenRecordChannel().startRecording(
      fps: 15,
      maxDurationMs: 1000,
      outputPath: '/tmp/a.mp4',
    );
    expect(r1?['status'], 'rejected');

    mock((call) async => {'status': 'cancelled'});
    final r2 = await const ScreenRecordChannel().startRecording(
      fps: 15,
      maxDurationMs: 1000,
      outputPath: '/tmp/b.mp4',
    );
    expect(r2?['status'], 'cancelled');

    mock((call) async => {'status': 'error', 'message': '编码器初始化失败'});
    final r3 = await const ScreenRecordChannel().startRecording(
      fps: 15,
      maxDurationMs: 1000,
      outputPath: '/tmp/c.mp4',
    );
    expect(r3?['status'], 'error');
    expect(r3?['message'], '编码器初始化失败');
  });

  test('stopRecording/cancelRecording 参数透传', () async {
    final methods = <String>[];
    mock((call) async {
      methods.add(call.method);
      return null;
    });

    const ch = ScreenRecordChannel();
    await ch.stopRecording();
    await ch.cancelRecording();
    expect(methods, ['stopRecording', 'cancelRecording']);
  });

  test('MissingPluginException(桌面宿主)→ 上抛,由端口包装为失败', () async {
    mock((call) async => throw MissingPluginException());

    expect(
      () => const ScreenRecordChannel().startRecording(
        fps: 15,
        maxDurationMs: 1000,
        outputPath: '/tmp/x.mp4',
      ),
      throwsA(isA<MissingPluginException>()),
    );
  });
}

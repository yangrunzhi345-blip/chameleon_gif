import 'package:ffmpeg_kit_flutter_minimal/media_information.dart';
import 'package:ffmpeg_kit_flutter_minimal/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_minimal/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/shared/platform/ffprobe_kit_executor.dart';

/// MediaInformationSession 的测试替身:仅实现 run() 用到的三个成员,
/// 其余经 noSuchMethod 兜底(该类是具体类,成员众多,不可在 Linux 实例化)。
class _FakeSession implements MediaInformationSession {
  _FakeSession({this.returnCodeValue, this.output = '', this.info});

  final int? returnCodeValue;
  final String output;
  final MediaInformation? info;

  @override
  Future<ReturnCode?> getReturnCode() async =>
      returnCodeValue == null ? null : ReturnCode(returnCodeValue!);

  @override
  Future<String?> getOutput() async => output;

  @override
  MediaInformation? getMediaInformation() => info;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake session 未实现: ${invocation.memberName}');
}

void main() {
  group('FfprobeKitFfprobeExecutor', () {
    test('探测抛异常 → FilePickException(GIF_PROBE_UNREACHABLE)', () async {
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async =>
            throw StateError('kit down'),
      );

      expect(
        () => executor.run('/tmp/a.mp4'),
        throwsA(
          isA<FilePickException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_PROBE_UNREACHABLE',
          ),
        ),
      );
    });

    test('exitCode 透传(成功 0)', () async {
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async =>
            _FakeSession(returnCodeValue: 0),
      );

      final result = await executor.run('/tmp/a.mp4');
      expect(result.exitCode, 0);
    });

    test('returnCode 为 null → exitCode -1', () async {
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async => _FakeSession(),
      );

      final result = await executor.run('/tmp/a.mp4');
      expect(result.exitCode, -1);
    });

    test('stderr(output)透传', () async {
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async =>
            _FakeSession(returnCodeValue: 1, output: 'ffprobe error line'),
      );

      final result = await executor.run('/tmp/a.mp4');
      expect(result.stderr, 'ffprobe error line');
    });

    test('mediaInformation 透传', () async {
      final info = MediaInformation(const {
        'format': {'filename': '/tmp/a.mp4', 'duration': '3.000000'},
      });
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async =>
            _FakeSession(returnCodeValue: 0, info: info),
      );

      final result = await executor.run('/tmp/a.mp4');
      expect(result.mediaInformation, same(info));
    });

    test('probeJson 取 getAllProperties(ffprobe JSON 结构),修复真机解析失败', () async {
      final info = MediaInformation(const {
        'format': {'filename': '/tmp/a.mp4', 'duration': '3.000000'},
        'streams': [
          {
            'codec_type': 'video',
            'codec_name': 'h264',
            'width': 1920,
            'height': 1080,
            'avg_frame_rate': '30/1',
          },
        ],
      });
      final executor = FfprobeKitFfprobeExecutor(
        getMediaInformation: (arguments, [waitTimeout]) async =>
            _FakeSession(returnCodeValue: 0, info: info),
      );

      final result = await executor.run('/tmp/a.mp4');
      expect(result.probeJson, isNotNull, reason: 'probeJson 不得为空');
      expect(result.probeJson!['format'], isA<Map>());
      expect(result.probeJson!['streams'], isA<List>());
    });
  });

  group('FfprobeKitFfprobeExecutor.probeArguments', () {
    test('参数数组直传(不走空格拆分,路径含空格安全,2026-08-07 回归锁定)', () {
      expect(
        FfprobeKitFfprobeExecutor.probeArguments(
          '/data/user/0/app/cache/file_picker/IMG 2024 test.jpg',
        ),
        [
          '-v',
          'error',
          '-hide_banner',
          '-print_format',
          'json',
          '-show_format',
          '-show_streams',
          '-show_chapters',
          '-i',
          '/data/user/0/app/cache/file_picker/IMG 2024 test.jpg',
        ],
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/features/converter/infrastructure/ffprobe_video_info_parser.dart';

import '../../fixtures/ffprobe_loader.dart';

void main() {
  const parser = FfprobeVideoInfoParser();

  /// 内联构造假 ffprobe 输出(公开构造,免夹具文件)
  Map<String, dynamic> buildProbeJson({
    List<Map<dynamic, dynamic>> streams = const [],
    String? duration,
    String formatName = 'mp4',
  }) {
    return <String, dynamic>{
      'streams': streams,
      'format': {'format_name': formatName, 'duration': duration},
    };
  }

  Map<dynamic, dynamic> videoStream({
    int width = 640,
    int height = 360,
    String avgFrameRate = '30000/1001',
    String realFrameRate = '30000/1001',
    String codec = 'h264',
    int index = 0,
  }) {
    return {
      'index': index,
      'codec_type': 'video',
      'codec_name': codec,
      'width': width,
      'height': height,
      'avg_frame_rate': avgFrameRate,
      'r_frame_rate': realFrameRate,
    };
  }

  group('FfprobeVideoInfoParser 标准解析', () {
    test('标准夹具:时长/分辨率/帧率/编码/格式名/路径全对', () {
      final info = parser.parseJson(
        loadFfprobeFixture('h264_640x360_29.97'),
        path: '/tmp/sample.mp4',
      );
      expect(info.path, '/tmp/sample.mp4');
      expect(info.formatName, 'mov,mp4,m4a,3gp,3g2,mj2');
      expect(info.duration, const Duration(milliseconds: 10533));
      expect(info.width, 640);
      expect(info.height, 360);
      expect(info.fps, closeTo(29.97, 0.001));
      expect(info.codec, 'h264');
    });

    test('多视频流取第一个', () {
      final info = parser.parseJson(
        buildProbeJson(
          streams: [
            videoStream(width: 1920, height: 1080, index: 0),
            videoStream(width: 1280, height: 720, index: 1),
          ],
          duration: '10.0',
        ),
        path: '/tmp/a.mp4',
      );
      expect(info.width, 1920);
      expect(info.height, 1080);
    });

    test('avg_frame_rate 为 0/0 时回退 r_frame_rate', () {
      final info = parser.parseJson(
        buildProbeJson(
          streams: [videoStream(avgFrameRate: '0/0', realFrameRate: '25/1')],
          duration: '10.0',
        ),
        path: '/tmp/a.mp4',
      );
      expect(info.fps, 25.0);
    });

    test('帧率全缺 → fps 为 null(不阻塞导入)', () {
      final info = parser.parseJson(
        buildProbeJson(
          streams: [videoStream(avgFrameRate: '0/0', realFrameRate: '0/0')],
          duration: '10.0',
        ),
        path: '/tmp/a.mp4',
      );
      expect(info.fps, isNull);
    });

    test('缺 codec → 兜底 unknown', () {
      final stream = videoStream();
      stream.remove('codec_name');
      final info = parser.parseJson(
        buildProbeJson(streams: [stream], duration: '10.0'),
        path: '/tmp/a.mp4',
      );
      expect(info.codec, 'unknown');
    });
  });

  group('FfprobeVideoInfoParser 异常样本', () {
    test('无视频流(纯音频)→ SourceBroken', () {
      expect(
        () => parser.parseJson(
          loadFfprobeFixture('audio_only'),
          path: '/tmp/a.m4a',
        ),
        throwsA(
          isA<SourceBrokenException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_PROBE_NO_VIDEO_STREAM',
          ),
        ),
      );
    });

    test('缺 duration → SourceBroken', () {
      expect(
        () => parser.parseJson(
          buildProbeJson(streams: [videoStream()]),
          path: '/tmp/a.mp4',
        ),
        throwsA(
          isA<SourceBrokenException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_PROBE_NO_DURATION',
          ),
        ),
      );
    });

    test('缺分辨率 → SourceBroken', () {
      final stream = videoStream();
      stream.remove('width');
      stream.remove('height');
      expect(
        () => parser.parseJson(
          buildProbeJson(streams: [stream], duration: '10.0'),
          path: '/tmp/a.mp4',
        ),
        throwsA(
          isA<SourceBrokenException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GIF_PROBE_NO_RESOLUTION',
          ),
        ),
      );
    });

    test('异常样本的 userMessage 为中文损坏提示', () {
      try {
        parser.parseJson(buildProbeJson(streams: []), path: '/tmp/a.mp4');
        fail('应当抛 SourceBrokenException');
      } on SourceBrokenException catch (e) {
        expect(e.userMessage, '视频文件损坏或格式异常');
      }
    });
  });

  group('frameRateFromFraction', () {
    test('分数求值', () {
      expect(
        FfprobeVideoInfoParser.frameRateFromFraction('30000/1001'),
        closeTo(29.97, 0.001),
      );
      expect(FfprobeVideoInfoParser.frameRateFromFraction('25/1'), 25.0);
      expect(FfprobeVideoInfoParser.frameRateFromFraction('30/1'), 30.0);
    });

    test('纯数字兜底', () {
      expect(FfprobeVideoInfoParser.frameRateFromFraction('29.97'), 29.97);
      expect(FfprobeVideoInfoParser.frameRateFromFraction('25'), 25.0);
    });

    test('非法输入 → null', () {
      expect(FfprobeVideoInfoParser.frameRateFromFraction('0/0'), isNull);
      expect(FfprobeVideoInfoParser.frameRateFromFraction('25/0'), isNull);
      expect(FfprobeVideoInfoParser.frameRateFromFraction(''), isNull);
      expect(FfprobeVideoInfoParser.frameRateFromFraction('abc'), isNull);
      expect(FfprobeVideoInfoParser.frameRateFromFraction(null), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/file_pick_exception.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/parse_video_port.dart';
import 'package:gif_forge/features/import/application/import_video_use_case.dart';

/// 手写 Fake 端口(成功/抛错两态),不依赖真实 ffprobe
class FakeParseVideoPort implements ParseVideoPort {
  FakeParseVideoPort({this.onParse});

  final Future<VideoInfo> Function(String path)? onParse;

  @override
  Future<VideoInfo> parse(String path) {
    final handler = onParse;
    if (handler != null) return handler(path);
    return Future.value(_sampleInfo(path));
  }

  static VideoInfo _sampleInfo(String path) => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 5),
    width: 640,
    height: 360,
    fps: 30.0,
    codec: 'h264',
  );
}

void main() {
  final logger = AppLogger();

  test('成功解析 → 原样返回 VideoInfo', () async {
    final useCase = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
    );
    final info = await useCase.execute('/tmp/sample.mp4');
    expect(info.path, '/tmp/sample.mp4');
    expect(info.width, 640);
    expect(info.fps, 30.0);
  });

  test('端口抛 SourceBrokenException → 原样上抛(类型断言)', () async {
    final useCase = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(
        onParse: (_) async =>
            throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN'),
      ),
      logger: logger,
    );
    expect(
      () => useCase.execute('/tmp/broken.mp4'),
      throwsA(
        isA<SourceBrokenException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_1_SOURCE_BROKEN',
        ),
      ),
    );
  });

  test('端口抛未知异常 → 包装为 GIF_PARSE_UNKNOWN 且保留 cause', () async {
    final useCase = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(
        onParse: (_) async => throw StateError('底层炸了'),
      ),
      logger: logger,
    );
    try {
      await useCase.execute('/tmp/a.mp4');
      fail('应当抛 FilePickException');
    } on FilePickException catch (e) {
      expect(e.errorCode, 'GIF_PARSE_UNKNOWN');
      expect(e.userMessage, '视频解析失败,请稍后重试');
      expect(e.cause, isA<StateError>());
    }
  });
}

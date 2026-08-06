import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/file_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/image_probe_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';

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

  test('pick*:端口注入时转发,取消/空返回 null,未注入返回 null', () async {
    final useCase = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
      filePickPort: _FakePickPort(
        mp4: '/tmp/a.mp4',
        mp4s: ['/tmp/a.mp4', '/tmp/b.mp4'],
        images: ['/img/1.png'],
      ),
    );
    expect(await useCase.pickVideoFile(), '/tmp/a.mp4');
    expect(await useCase.pickVideoFiles(), ['/tmp/a.mp4', '/tmp/b.mp4']);
    expect(await useCase.pickImages(), ['/img/1.png']);

    final noPort = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
    );
    expect(await noPort.pickVideoFile(), isNull);
    expect(await noPort.pickVideoFiles(), isNull);
    expect(await noPort.pickImages(), isNull);
  });

  test('probeImageSize:成功返回尺寸,失败归一 null,未注入 null', () async {
    final useCase = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
      imageProbePort: _FakeProbe(),
    );
    expect(await useCase.probeImageSize('/img/a.png'), (width: 64, height: 64));

    final failing = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
      imageProbePort: _FakeProbe(error: StateError('decode')),
    );
    expect(await failing.probeImageSize('/img/broken.png'), isNull);

    final noPort = ImportVideoUseCase(
      parseVideoPort: FakeParseVideoPort(),
      logger: logger,
    );
    expect(await noPort.probeImageSize('/img/a.png'), isNull);
  });
}

class _FakePickPort implements FilePickPort {
  _FakePickPort({this.mp4, this.mp4s, this.images});

  final String? mp4;
  final List<String>? mp4s;
  final List<String>? images;

  @override
  Future<String?> pickMp4() async => mp4;

  @override
  Future<List<String>?> pickMp4s() async => mp4s;

  @override
  Future<List<String>?> pickImages() async => images;
}

class _FakeProbe implements ImageProbePort {
  _FakeProbe({this.error});

  final Object? error;

  @override
  Future<({int width, int height})> probe(String path) async {
    if (error != null) throw error!;
    return (width: 64, height: 64);
  }
}

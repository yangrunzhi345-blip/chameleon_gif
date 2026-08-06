import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/capture_import_use_case.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
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

/// [CaptureImportUseCase] 测试:解析 → onImported 回调衔接、异常语义。
void main() {
  final logger = AppLogger();

  CaptureImportUseCase buildCase(
    FakeParseVideoPort port, {
    required void Function(VideoInfo) onImported,
  }) {
    return CaptureImportUseCase(
      importVideoUseCase: ImportVideoUseCase(
        parseVideoPort: port,
        logger: logger,
      ),
      onImported: (video, source) async => onImported(video),
      logger: logger,
    );
  }

  test('成功解析 → onImported 收到 VideoInfo 且返回同对象', () async {
    VideoInfo? imported;
    final useCase = buildCase(
      FakeParseVideoPort(),
      onImported: (v) => imported = v,
    );

    final info = await useCase.execute(
      '/tmp/captures/capture_1.mp4',
      source: CaptureSource.camera,
    );

    expect(info.path, '/tmp/captures/capture_1.mp4');
    expect(imported, same(info), reason: '回调收到解析结果同一实例');
  });

  test('端口抛 SourceBrokenException → 透传且 onImported 不调用', () async {
    var onImportedCalled = false;
    final useCase = buildCase(
      FakeParseVideoPort(
        onParse: (_) async =>
            throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN'),
      ),
      onImported: (_) => onImportedCalled = true,
    );

    expect(
      () => useCase.execute('/tmp/broken.mp4', source: CaptureSource.camera),
      throwsA(
        isA<SourceBrokenException>().having(
          (e) => e.errorCode,
          'errorCode',
          'GIF_1_SOURCE_BROKEN',
        ),
      ),
    );
    expect(onImportedCalled, isFalse, reason: '解析失败不触发跳转');
  });

  test('端口抛未知异常 → 包装为 GIF_PARSE_UNKNOWN 且保留 cause', () async {
    final useCase = buildCase(
      FakeParseVideoPort(onParse: (_) async => throw StateError('底层炸了')),
      onImported: (_) => fail('不应触发跳转'),
    );

    try {
      await useCase.execute('/tmp/a.mp4', source: CaptureSource.camera);
      fail('应当抛 FilePickException');
    } on FilePickException catch (e) {
      expect(e.errorCode, 'GIF_PARSE_UNKNOWN');
      expect(e.userMessage, '视频解析失败,请稍后重试');
      expect(e.cause, isA<StateError>());
    }
  });
}

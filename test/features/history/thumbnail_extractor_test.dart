import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:gif_forge/features/history/infrastructure/thumbnail_extractor.dart';

/// 缩略图假 PNG 字节(无需真实 PNG 编码,extractor 只 readAsBytes 透传)。
final _thumbBytes = Uint8List.fromList(List.generate(16, (i) => i));

/// 抽帧引擎替身:记录收到的命令,成功时真实写 PNG 到命令最后一项路径。
///
/// 与 ffmpeg_service_engine_test.dart 的 FakeEngine 同模式,增强"写文件"
/// 与"抛异常"两态以覆盖成功分支与失败降级。
class _FakeEngine implements FFmpegEngine {
  int exitCode = 0;
  bool writeFile = true;
  bool throwOnRun = false;

  final List<List<String>> commands = [];

  @override
  Future<ConvertResult> convert(
    ConvertRequest request, {
    void Function(String line)? onProgress,
    void Function(String line)? onLog,
    CancelToken? cancelToken,
  }) async {
    commands.add(request.command);
    if (throwOnRun) {
      throw const FileSystemException('fake engine failure');
    }
    if (writeFile && exitCode == 0) {
      final file = File(request.command.last);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(_thumbBytes);
    }
    return ConvertResult(
      exitCode: exitCode,
      elapsed: Duration.zero,
      outputSizeBytes: (writeFile && exitCode == 0) ? _thumbBytes.length : null,
    );
  }
}

void main() {
  late String cacheDir;
  late _FakeEngine engine;
  late ThumbnailExtractor extractor;

  setUp(() async {
    cacheDir = Directory.systemTemp.createTempSync('thumb_test_').path;
    engine = _FakeEngine();
    extractor = ThumbnailExtractor(
      engine: engine,
      cacheDir: cacheDir,
      logger: AppLogger(),
    );
  });

  tearDown(() async {
    await Directory(cacheDir).delete(recursive: true);
  });

  group('ThumbnailExtractor(内存缓存)', () {
    test('命令装配正确,成功返回写入字节', () async {
      const videoPath = '/tmp/source/video.mp4';

      final bytes = await extractor.extract(videoPath);

      expect(engine.commands, hasLength(1));
      expect(engine.commands.single, [
        '-ss',
        '0',
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-y',
        '$cacheDir/thumb_${videoPath.hashCode}.png',
      ]);
      expect(bytes, _thumbBytes);
    });

    test('缓存命中不重复抽帧', () async {
      const videoPath = '/tmp/source/video.mp4';

      final first = await extractor.extract(videoPath);
      final second = await extractor.extract(videoPath);

      expect(engine.commands, hasLength(1));
      expect(first, _thumbBytes);
      expect(second, _thumbBytes);
    });

    test('并发调用共享同一 Future(putIfAbsent 幂等)', () async {
      const videoPath = '/tmp/source/video.mp4';

      final a = extractor.extract(videoPath);
      final b = extractor.extract(videoPath);

      expect(identical(a, b), isTrue);
      expect(await a, _thumbBytes);
      expect(engine.commands, hasLength(1));
    });

    test('64 条 FIFO 上限:最旧键被逐出后需重新抽帧', () async {
      final paths = List.generate(65, (i) => '/tmp/source/video_$i.mp4');

      for (final path in paths) {
        await extractor.extract(path);
      }
      expect(engine.commands, hasLength(65));

      // 第 1 条已被逐出 → 重新抽帧
      await extractor.extract(paths.first);
      expect(engine.commands, hasLength(66));

      // 第 65 条仍在缓存 → 命中
      await extractor.extract(paths.last);
      expect(engine.commands, hasLength(66));
    });

    test('exitCode != 0 → null(失败降级,不抛)', () async {
      engine.exitCode = 1;

      final bytes = await extractor.extract('/tmp/source/video.mp4');

      expect(bytes, isNull);
      expect(engine.commands, hasLength(1));
    });

    test('退出码为 0 但无输出文件 → null', () async {
      engine.writeFile = false;

      final bytes = await extractor.extract('/tmp/source/video.mp4');

      expect(bytes, isNull);
    });

    test('引擎抛异常 → null(全兜底降级)', () async {
      engine.throwOnRun = true;

      final bytes = await extractor.extract('/tmp/source/video.mp4');

      expect(bytes, isNull);
    });

    test('cacheDir 不存在时自动创建', () async {
      final freshDir = Directory.systemTemp.createTempSync('thumb_test_').path;
      await Directory(freshDir).delete();
      final fresh = ThumbnailExtractor(
        engine: engine,
        cacheDir: freshDir,
        logger: AppLogger(),
      );
      addTearDown(() => Directory(freshDir).delete(recursive: true));

      final bytes = await fresh.extract('/tmp/source/video.mp4');

      expect(bytes, _thumbBytes);
      expect(Directory(freshDir).existsSync(), isTrue);
    });
  });
}

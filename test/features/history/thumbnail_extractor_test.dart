import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/features/history/infrastructure/thumbnail_extractor.dart';

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
      final pngPath = engine.commands.single.last;
      expect(engine.commands.single, [
        '-ss',
        '0',
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-y',
        pngPath,
      ]);
      // 磁盘文件名:稳定 key(长度前缀 + base64Url,非 hashCode)
      expect(pngPath, startsWith('$cacheDir/thumb_${videoPath.length}_'));
      expect(pngPath, endsWith('.png'));
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

    test('64 条 FIFO 上限:最旧键被逐出重建 Future,磁盘兜底不重复抽帧', () async {
      final paths = List.generate(65, (i) => '/tmp/source/video_$i.mp4');

      final futures = [for (final p in paths) extractor.extract(p)];
      await Future.wait(futures);
      expect(engine.commands, hasLength(65));

      // 第 1 条已被内存逐出:重新 extract 得到新 Future(非 identical)
      final again = extractor.extract(paths.first);
      expect(identical(again, futures.first), isFalse, reason: '已逐出重建');

      // 但磁盘层兜底:同路径缩略图仍在磁盘,不重复起进程
      await again;
      expect(engine.commands, hasLength(65));

      // 第 65 条仍在内存缓存:直接命中,仍无新进程
      await extractor.extract(paths.last);
      expect(engine.commands, hasLength(65));
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

  group('ThumbnailExtractor(磁盘缓存)', () {
    ThumbnailExtractor newExtractor(_FakeEngine e) =>
        ThumbnailExtractor(engine: e, cacheDir: cacheDir, logger: AppLogger());

    test('跨实例磁盘命中:新 extractor 不重复抽帧(源缺失也命中)', () async {
      const videoPath = '/tmp/source/video.mp4';
      await extractor.extract(videoPath); // 实例 A 抽帧落盘

      final engineB = _FakeEngine();
      final bytes = await newExtractor(engineB).extract(videoPath);

      expect(engineB.commands, isEmpty, reason: '磁盘命中,不起新进程');
      expect(bytes, _thumbBytes);
    });

    test('源文件更新后新实例重新抽帧(磁盘命中失效)', () async {
      final src = File('$cacheDir/../src_updated.mp4');
      await src.writeAsBytes([1, 2, 3]);
      addTearDown(() => src.delete());

      await extractor.extract(src.path); // 实例 A 落盘
      await src.setLastModified(
        DateTime.now().add(const Duration(seconds: 10)),
      );

      final engineB = _FakeEngine();
      final bytes = await newExtractor(engineB).extract(src.path);

      expect(engineB.commands, hasLength(1), reason: '源更新 → 重新抽帧');
      expect(bytes, _thumbBytes);
    });

    test('磁盘异常(同名目录占位):不返回缓存,回落重抽,失败时降级 null', () async {
      const videoPath = '/tmp/source/video.mp4';
      await extractor.extract(videoPath); // 实例 A 落盘

      // 以同名目录顶替 png 文件:磁盘读失败(非文件)→ 不命中缓存
      final png = Directory(cacheDir).listSync().whereType<File>().single;
      png.deleteSync();
      Directory(png.path).createSync();
      addTearDown(() {
        if (Directory(png.path).existsSync()) Directory(png.path).deleteSync();
      });

      final engineB = _FakeEngine();
      final bytes = await newExtractor(engineB).extract(videoPath);

      expect(engineB.commands, hasLength(1), reason: '磁盘异常 → 回落重抽');
      expect(bytes, isNull, reason: '重抽写盘被占位挡路 → null 降级,不抛');
    });

    test('首次使用惰性清扫:超 256 张按 mtime 删除最旧', () async {
      // 预置 257 张,写入时间递增,最旧为 thumb_0.png
      final base = DateTime.now().subtract(const Duration(hours: 1));
      for (var i = 0; i < 257; i++) {
        final f = File('$cacheDir/thumb_$i.png')..writeAsBytesSync([i % 256]);
        f.setLastModifiedSync(base.add(Duration(minutes: i)));
      }

      final engineB = _FakeEngine();
      await newExtractor(engineB).extract('/tmp/source/video.mp4');

      final remaining = Directory(cacheDir).listSync().whereType<File>().length;
      expect(remaining, 257, reason: '清扫删 1(至 256)+ 新抽帧 1');
      expect(
        File('$cacheDir/thumb_0.png').existsSync(),
        isFalse,
        reason: '最旧被清',
      );
      expect(File('$cacheDir/thumb_256.png').existsSync(), isTrue);
    });
  });
}

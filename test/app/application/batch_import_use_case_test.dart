import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/batch_import_use_case.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';

/// [BatchImportUseCase] 测试(P6-WP1):批量入队/失败隔离/参数透传。
/// 参数装配(默认参数/原图等比)在 BatchImportController.init,不在本用例。
void main() {
  final logger = AppLogger();

  VideoInfo video(String path) => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );

  test('3 文件 → 3 任务入队,end 强制全长,outputDir 透传', () async {
    final submitted = <(GifSetting, VideoInfo, String?)>[];
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(onExecute: video),
      submit: (setting, v, {String? outputDir}) async {
        submitted.add((setting, v, outputDir));
        return submitted.length;
      },
      logger: logger,
    );

    final result = await useCase.execute(
      ['/tmp/a.mp4', '/tmp/b.mp4', '/tmp/c.mp4'],
      setting: const GifSetting(fps: 24, width: 480, loop: 2),
      outputDir: '/home/u/GIF',
    );

    expect(result.enqueued, 3);
    expect(result.failed, 0);
    expect(submitted, hasLength(3));
    expect(submitted[0].$2.path, '/tmp/a.mp4');
    expect(submitted[0].$1.end, isNull, reason: 'end 强制 null 由入队时装配全长');
    expect(submitted[0].$1.fps, 24, reason: '调用方 setting 透传');
    expect(submitted[0].$1.width, 480, reason: '调用方 setting 透传');
    expect(submitted[0].$1.loop, 2, reason: '调用方 setting 透传');
    expect(submitted[0].$3, '/home/u/GIF', reason: 'outputDir 透传');
  });

  test('outputDir 空串 → null(系统临时目录)', () async {
    final submitted = <(GifSetting, VideoInfo, String?)>[];
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(onExecute: video),
      submit: (setting, v, {String? outputDir}) async {
        submitted.add((setting, v, outputDir));
        return submitted.length;
      },
      logger: logger,
    );

    await useCase.execute(
      ['/tmp/a.mp4'],
      setting: const GifSetting(),
      outputDir: '',
    );

    expect(submitted[0].$3, isNull);
  });

  test('单文件解析失败 → 跳过,其余入队(失败隔离)', () async {
    final submitted = <String>[];
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(
        onExecute: (path) {
          if (path == '/tmp/broken.mp4') {
            throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
          }
          return video(path);
        },
      ),
      submit: (setting, v, {String? outputDir}) async {
        submitted.add(v.path);
        return submitted.length;
      },
      logger: logger,
    );

    final result = await useCase.execute([
      '/tmp/a.mp4',
      '/tmp/broken.mp4',
      '/tmp/c.mp4',
    ], setting: const GifSetting());

    expect(result.enqueued, 2);
    expect(result.failed, 1);
    expect(submitted, ['/tmp/a.mp4', '/tmp/c.mp4']);
  });

  test('全部失败 → enqueued 0', () async {
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(
        onExecute: (_) =>
            throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN'),
      ),
      submit: (setting, v, {String? outputDir}) async => 1,
      logger: logger,
    );

    final result = await useCase.execute([
      '/tmp/a.mp4',
      '/tmp/b.mp4',
    ], setting: const GifSetting());
    expect(result.enqueued, 0);
    expect(result.failed, 2);
  });
}

class _FakeImportUseCase implements ImportVideoUseCase {
  _FakeImportUseCase({required this.onExecute});

  final VideoInfo Function(String path) onExecute;

  @override
  Future<VideoInfo> execute(String path) async => onExecute(path);
}

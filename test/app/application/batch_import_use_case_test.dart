import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/batch_import_use_case.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/settings_repository.dart';
import 'package:chameleon_gif/domain/value_objects/app_theme_mode.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';

/// [BatchImportUseCase] 测试(P6-WP1):批量入队/失败隔离/参数装配。
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

  test('3 文件 → 3 任务入队,end 全长,outputDir 取默认导出目录', () async {
    final submitted = <(GifSetting, VideoInfo, String?)>[];
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(onExecute: video),
      submit: (setting, v, {String? outputDir}) async {
        submitted.add((setting, v, outputDir));
        return submitted.length;
      },
      settingsRepository: _FakeSettings(defaultExportDir: '/home/u/GIF'),
      logger: logger,
    );

    final result = await useCase.execute([
      '/tmp/a.mp4',
      '/tmp/b.mp4',
      '/tmp/c.mp4',
    ]);

    expect(result.enqueued, 3);
    expect(result.failed, 0);
    expect(submitted, hasLength(3));
    expect(submitted[0].$2.path, '/tmp/a.mp4');
    expect(submitted[0].$1.end, isNull, reason: 'end 留 null 由入队时装配全长');
    expect(submitted[0].$3, '/home/u/GIF', reason: '默认导出目录透传');
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
      settingsRepository: _FakeSettings(),
      logger: logger,
    );

    final result = await useCase.execute([
      '/tmp/a.mp4',
      '/tmp/broken.mp4',
      '/tmp/c.mp4',
    ]);

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
      settingsRepository: _FakeSettings(),
      logger: logger,
    );

    final result = await useCase.execute(['/tmp/a.mp4', '/tmp/b.mp4']);
    expect(result.enqueued, 0);
    expect(result.failed, 2);
  });

  test('默认参数:其余默认保留,宽高强制原图等比(忽略已保存固定宽高)', () async {
    GifSetting? submitted;
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(onExecute: video),
      submit: (setting, v, {String? outputDir}) async {
        submitted = setting;
        return 1;
      },
      settingsRepository: _FakeSettings(
        defaultSetting: const GifSetting(
          fps: 24,
          width: 640,
          height: 360,
          loop: 2,
        ),
      ),
      logger: logger,
    );

    await useCase.execute(['/tmp/a.mp4']);

    expect(submitted!.fps, 24, reason: 'fps 默认参数保留');
    expect(submitted!.loop, 2, reason: '循环默认参数保留');
    expect(submitted!.width, 0, reason: '批量导入宽高强制原图等比');
    expect(submitted!.height, 0, reason: '批量导入宽高强制原图等比');
  });
}

class _FakeImportUseCase implements ImportVideoUseCase {
  _FakeImportUseCase({required this.onExecute});

  final VideoInfo Function(String path) onExecute;

  @override
  Future<VideoInfo> execute(String path) async => onExecute(path);
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings({this.defaultExportDir = '', this.defaultSetting});

  @override
  final String defaultExportDir;

  final GifSetting? defaultSetting;

  @override
  AppThemeMode get themeMode => AppThemeMode.system;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}

  @override
  String get language => 'zh';

  @override
  Future<void> setLanguage(String language) async {}

  @override
  String? get lastImportDir => null;

  @override
  Future<void> setLastImportDir(String path) async {}

  @override
  Future<void> setDefaultExportDir(String path) async {}

  @override
  GifSetting? get defaultGifSetting => defaultSetting;

  @override
  Future<void> setDefaultGifSetting(GifSetting setting) async {}
}

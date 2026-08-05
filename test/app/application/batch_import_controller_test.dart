import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/batch_import_controller.dart';
import 'package:chameleon_gif/app/application/batch_import_state.dart';
import 'package:chameleon_gif/app/application/batch_import_use_case.dart';
import 'package:chameleon_gif/app/application/providers.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/directory_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/settings_repository.dart';
import 'package:chameleon_gif/domain/value_objects/app_theme_mode.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/import/application/import_video_use_case.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

/// [BatchImportController] 测试(纯 Dart ProviderContainer,注入 Fake)。
void main() {
  late _FakeSettings settings;
  late _FakeDirPick dirPick;
  late ProviderContainer container;

  /// 记录 submit 收到的 (setting, video, outputDir)。
  final submitted = <(GifSetting, VideoInfo, String?)>[];

  ProviderContainer build({GifSetting? defaultSetting}) {
    settings = _FakeSettings(
      defaultSetting: defaultSetting,
      defaultExportDir: defaultSetting == null ? '' : '/home/u/GIF',
    );
    dirPick = _FakeDirPick();
    submitted.clear();
    final useCase = BatchImportUseCase(
      importVideoUseCase: _FakeImportUseCase(),
      submit: (setting, v, {String? outputDir}) async {
        submitted.add((setting, v, outputDir));
        return submitted.length;
      },
      logger: AppLogger(),
    );
    return ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        directoryPickPortProvider.overrideWithValue(dirPick),
        batchImportUseCaseProvider.overrideWithValue(useCase),
      ],
    )..listen(batchImportControllerProvider, (_, _) {}); // 保持 autoDispose 存活
  }

  setUp(() {
    container = build();
  });

  tearDown(() {
    container.dispose();
  });

  BatchImportFormState state() => container.read(batchImportControllerProvider);

  BatchImportController ctl() =>
      container.read(batchImportControllerProvider.notifier);

  test('init:持久化默认继承 fps/loop/start,宽高强制 0,end null,目录取默认', () {
    container = build(
      defaultSetting: const GifSetting(
        fps: 24,
        width: 640,
        height: 360,
        loop: 2,
        start: Duration(seconds: 5),
      ),
    );
    ctl().init();

    expect(state().fps, 24, reason: 'fps 继承持久化默认');
    expect(state().loop, 2, reason: 'loop 继承持久化默认');
    expect(state().start, const Duration(seconds: 5), reason: 'start 继承');
    expect(state().width, 0, reason: '宽高强制原图等比');
    expect(state().height, 0, reason: '宽高强制原图等比');
    expect(state().end, isNull, reason: 'end 强制 null 全长');
    expect(state().outputDir, '/home/u/GIF', reason: '默认导出目录');
  });

  test('init:无持久化默认 → 内置默认', () {
    ctl().init();

    expect(state().fps, 15.0);
    expect(state().width, 0);
    expect(state().height, 0);
    expect(state().loop, 0);
    expect(state().start, Duration.zero);
    expect(state().end, isNull);
    expect(state().outputDir, isNull, reason: '默认导出目录空 → null');
  });

  test('init:宽高强制 0 时继承默认倍数(入队按各文件尺寸展开)', () {
    container = build(defaultSetting: const GifSetting(scaleMultiplier: 2.0));
    ctl().init();

    expect(state().scaleMultiplier, 2.0, reason: '倍数偏好继承');
    expect(state().width, 0);
    expect(state().height, 0);
  });

  test('updateScaleMultiplier:重置宽高 0 仅存倍数;手动宽高 → 自定义', () {
    ctl().init();
    ctl().updateWidth(480);
    expect(state().scaleMultiplier, isNull, reason: '手动宽高 → 自定义');

    ctl().updateScaleMultiplier(2.0);
    expect(state().scaleMultiplier, 2.0);
    expect(state().width, 0, reason: '选倍数 = 等比语义,宽高重置');
    expect(state().height, 0);

    ctl().updateWidth(640);
    expect(state().scaleMultiplier, isNull, reason: '再手动改宽高 → 自定义');
    // 恢复 (0,0) 原图等比 → 1.0(不缩放;选倍数偏好已被手动操作覆盖)
    ctl().updateWidth(0);
    ctl().updateHeight(0);
    expect(state().scaleMultiplier, 1.0, reason: '恢复原图等比 → 1.0');
  });

  test('update*:钳制并清 formError', () {
    ctl().init();
    ctl().updateFormError('旧错误');

    ctl().updateFps(99);
    expect(state().fps, 60);
    ctl().updateFps(-5);
    expect(state().fps, 1);

    ctl().updateWidth(-5);
    expect(state().width, 0);
    ctl().updateWidth(5000);
    expect(state().width, 4096);

    ctl().updateHeight(1080);
    expect(state().height, 1080);

    ctl().updateLoop(200);
    expect(state().loop, 100);

    expect(state().formError, isNull, reason: '更新清空 formError');
  });

  test('updateStart/updateEnd:负值钳 0,start>end 自动交换', () {
    ctl().init();

    ctl().updateStart(const Duration(seconds: -3));
    expect(state().start, Duration.zero);

    ctl().updateStart(const Duration(seconds: 20));
    ctl().updateEnd(const Duration(seconds: 10));
    expect(state().start, const Duration(seconds: 10), reason: '自动交换');
    expect(state().end, const Duration(seconds: 20));

    ctl().updateEnd(null);
    expect(state().end, isNull, reason: 'null = 全长');
    expect(state().start, const Duration(seconds: 10), reason: 'start 保留');
  });

  test('start:setting/outputDir/paths 透传,结果回传', () async {
    ctl().init();
    ctl().updateFps(30);
    ctl().updateWidth(480);
    ctl().updateOutputDir('/out');

    final result = await ctl().start(['/tmp/a.mp4', '/tmp/b.mp4']);

    expect(result.enqueued, 2);
    expect(result.failed, 0);
    expect(submitted, hasLength(2));
    final (setting, video, outputDir) = submitted[0];
    expect(setting.fps, 30);
    expect(setting.width, 480);
    expect(setting.end, isNull);
    expect(video.path, '/tmp/a.mp4');
    expect(outputDir, '/out');
  });

  test('start:end 非空且 start>=end → 拒绝,不调用用例', () async {
    ctl().init();
    // start == end:normalizeRange 相等不交换,保持 start>=end 触发拒绝
    ctl().updateStart(const Duration(seconds: 10));
    ctl().updateEnd(const Duration(seconds: 10));

    final result = await ctl().start(['/tmp/a.mp4']);

    expect(result.enqueued, 0);
    expect(result.failed, 0);
    expect(submitted, isEmpty, reason: '用例未被调用');
    expect(state().formError, '起点不能晚于或等于终点');
  });

  test('start:重入守卫,并发调用只执行一次', () async {
    ctl().init();
    final gate = _HangingUseCase();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        directoryPickPortProvider.overrideWithValue(dirPick),
        batchImportUseCaseProvider.overrideWithValue(gate),
      ],
    )..listen(batchImportControllerProvider, (_, _) {});
    final c = container.read(batchImportControllerProvider.notifier);

    final f1 = c.start(['/tmp/a.mp4']);
    final f2 = c.start(['/tmp/b.mp4']); // 第一轮未完成,应被忽略

    gate.release();
    final r1 = await f1;
    final r2 = await f2;

    expect(gate.callCount, 1, reason: '重入被守卫');
    expect(r1.enqueued, 1);
    expect(r2.enqueued, 0);
    container.dispose();
  });

  test('pickOutputDir:成功回填并持久化默认目录', () async {
    ctl().init();
    dirPick.result = '/new/dir';

    await ctl().pickOutputDir();

    expect(state().outputDir, '/new/dir');
    expect(settings.lastSetExportDir, '/new/dir', reason: '持久化默认导出目录');
  });

  test('pickOutputDir:取消(null)静默', () async {
    ctl().init();
    dirPick.result = null;

    await ctl().pickOutputDir();

    expect(state().outputDir, isNull, reason: '保持原值');
    expect(settings.lastSetExportDir, isNull);
  });

  test('pickOutputDir:选择失败 → formError 中文提示', () async {
    ctl().init();
    dirPick.error = const FilePickException(
      errorCode: 'GIF_PICK_DIR_FAILED',
      userMessage: '目录选择失败',
    );

    await ctl().pickOutputDir();

    expect(state().formError, '目录选择失败');
  });
}

/// 可挂起/释放的用例桩(重入守卫测试)。
class _HangingUseCase extends BatchImportUseCase {
  _HangingUseCase()
    : super(
        importVideoUseCase: _FakeImportUseCase(),
        submit: (setting, v, {String? outputDir}) async => 1,
        logger: AppLogger(),
      );

  final Completer<void> _gate = Completer<void>();
  int callCount = 0;

  void release() => _gate.complete();

  @override
  Future<BatchImportResult> execute(
    List<String> paths, {
    required GifSetting setting,
    String? outputDir,
  }) async {
    callCount++;
    await _gate.future;
    return const BatchImportResult(enqueued: 1, failed: 0);
  }
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings({this.defaultSetting, this.defaultExportDir = ''});

  final GifSetting? defaultSetting;
  @override
  final String defaultExportDir;

  String? lastSetExportDir;

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
  Future<void> setDefaultExportDir(String path) async {
    lastSetExportDir = path;
  }

  @override
  GifSetting? get defaultGifSetting => defaultSetting;

  @override
  Future<void> setDefaultGifSetting(GifSetting setting) async {}
}

class _FakeDirPick implements DirectoryPickPort {
  String? result;
  FilePickException? error;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    if (error != null) throw error!;
    return result;
  }
}

class _FakeImportUseCase implements ImportVideoUseCase {
  @override
  Future<VideoInfo> execute(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 10),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/application/batch_import_state.dart';
import 'package:chameleon_gif/app/application/settings_controller.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/directory_pick_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/settings_repository.dart';
import 'package:chameleon_gif/domain/value_objects/app_theme_mode.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';

/// [SettingsController] 测试:原样载入/save 持久化/mixin 共享表单路径。
/// 与 BatchImportController 的语义差异(原样 vs 强制宽高 0/end null)显式断言。
void main() {
  late _FakeSettings settings;
  late _FakeDirPick dirPick;
  late ProviderContainer container;

  ProviderContainer build({GifSetting? defaultSetting}) {
    settings = _FakeSettings(
      defaultSetting: defaultSetting,
      defaultExportDir: defaultSetting == null ? '' : '/home/u/GIF',
    );
    dirPick = _FakeDirPick();
    return ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        directoryPickPortProvider.overrideWithValue(dirPick),
      ],
    )..listen(settingsControllerProvider, (_, _) {}); // 保持 autoDispose 存活
  }

  setUp(() {
    container = build();
  });

  tearDown(() {
    container.dispose();
  });

  BatchImportFormState state() => container.read(settingsControllerProvider);

  SettingsController ctl() =>
      container.read(settingsControllerProvider.notifier);

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

  test('init:有持久化默认 → 原样载入(与批量会话的强制改写语义不同)', () {
    container = build(
      defaultSetting: const GifSetting(
        fps: 24,
        width: 640,
        height: 360,
        loop: 2,
        start: Duration(seconds: 5),
        end: Duration(seconds: 30),
      ),
    );
    ctl().init();

    expect(state().fps, 24);
    expect(state().width, 640, reason: '设置页原样显示,不强制 0');
    expect(state().height, 360, reason: '设置页原样显示,不强制 0');
    expect(state().loop, 2);
    expect(state().start, const Duration(seconds: 5));
    expect(state().end, const Duration(seconds: 30), reason: 'end 原样保留');
    expect(state().outputDir, '/home/u/GIF');
  });

  test('update*:钳制并清 formError(mixin 共享路径)', () {
    ctl().init();
    ctl().updateFormError('旧错误');

    ctl().updateFps(99);
    expect(state().fps, 60);
    ctl().updateWidth(-5);
    expect(state().width, 0);
    ctl().updateHeight(5000);
    expect(state().height, 4096);
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
    expect(state().end, isNull);
  });

  test('save:装配一致写回默认参数与导出目录', () async {
    ctl().init();
    ctl().updateFps(30);
    ctl().updateWidth(480);
    ctl().updateOutputDir('/out');

    await ctl().save();

    final saved = settings.lastSetGifSetting!;
    expect(saved.fps, 30);
    expect(saved.width, 480);
    expect(saved.end, isNull, reason: '装配含当前表单值');
    expect(settings.lastSetExportDir, '/out');
  });

  test('save:outputDir 为 null → 写回空串', () async {
    ctl().init();
    ctl().updateFps(20);

    await ctl().save();

    expect(settings.lastSetExportDir, '', reason: 'null 目录持久化为空串');
  });

  test('pickOutputDir:成功回填并持久化默认目录', () async {
    ctl().init();
    dirPick.result = '/new/dir';

    await ctl().pickOutputDir();

    expect(state().outputDir, '/new/dir');
    expect(settings.lastSetExportDir, '/new/dir');
  });

  test('pickOutputDir:取消(null)静默', () async {
    ctl().init();
    dirPick.result = null;

    await ctl().pickOutputDir();

    expect(state().outputDir, isNull);
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

class _FakeSettings implements SettingsRepository {
  _FakeSettings({this.defaultSetting, this.defaultExportDir = ''});

  final GifSetting? defaultSetting;
  @override
  final String defaultExportDir;

  GifSetting? lastSetGifSetting;
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
  Future<void> setDefaultGifSetting(GifSetting setting) async {
    lastSetGifSetting = setting;
  }

  @override
  CaptureParams? get captureParams => null;

  @override
  Future<void> setCaptureParams(CaptureParams params) async {}

  @override
  String get captureDeviceId => 'back';

  @override
  Future<void> setCaptureDeviceId(String deviceId) async {}

  @override
  RecordParams? get recordParams => null;

  @override
  Future<void> setRecordParams(RecordParams params) async {}
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

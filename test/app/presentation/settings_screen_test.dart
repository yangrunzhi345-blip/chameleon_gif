import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/batch_parameter_form.dart';
import 'package:chameleon_gif/app/presentation/settings_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/image_gif_source.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/source_broken_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_service.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import '../../fixtures/fake_camera_port.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';

/// 设置界面(P9.5):主题切换 + 批量导入默认参数编辑/保存/回显。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('gifforge_settings_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefsValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    // 加高测试窗口:批量参数表单 + 相机分组后,"保存设置"按钮在
    // 1280×900 视口外(相机分组新增约 400px 内容)
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final adapter = _TestAdapter(tempRoot.path);
    final service = _FakeService();
    final app = ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        cameraPortProvider.overrideWithValue(FakeCameraPort()),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(service),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: service,
            platformAdapter: adapter,
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: ChameleonGifApp(router: GoRouter(routes: buildRoutes())),
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  /// 进入设置界面(fake async 中不能直接 await push,先启动再 settle)。
  Future<void> enterSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  /// 输入时间文本并触发 onSubmitted。
  Future<void> submitTime(
    WidgetTester tester,
    Finder field,
    String text,
  ) async {
    await tester.enterText(field, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('渲染:主题三态 + 批量默认参数表单 + 保存按钮', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    expect(find.text('外观'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('批量导入默认参数'), findsOneWidget);
    expect(find.text('保存后,批量导入将默认使用以下参数'), findsOneWidget);
    // 帧率在批量表单与相机分组各一处,断言限定批量表单内
    expect(
      find.descendant(
        of: find.byType(BatchParameterForm),
        matching: find.text('帧率'),
      ),
      findsOneWidget,
    );
    expect(find.text('宽度'), findsOneWidget);
    expect(find.text('高度'), findsOneWidget);
    expect(find.text('循环'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);
    expect(find.text('保存设置'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存设置'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('无持久化默认 → 内置默认(15 fps)', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    // 15 fps 在批量表单与相机分组各一处,断言限定批量表单内
    expect(
      find.descendant(
        of: find.byType(BatchParameterForm),
        matching: find.text('15 fps'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('预置默认 → 原样回显', (tester) async {
    await pumpApp(
      tester,
      prefsValues: {
        'default_gif_setting': jsonEncode({
          'fps': 24.0,
          'width': 640,
          'height': 480, // 需在选项表内(360 不在候选,收起态回退首项)
          'loop': 2,
          'start': 5000000, // 5s(微秒)
          'end': 30000000, // 30s
        }),
        'default_export_dir': '/home/u/GIF',
      },
    );
    await enterSettings(tester);

    expect(find.text('24 fps'), findsOneWidget);
    expect(find.text('640 px'), findsOneWidget);
    expect(find.text('480 px'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget, reason: '循环回显');
    expect(find.widgetWithText(TextField, '00:05.000'), findsOneWidget);
    expect(find.widgetWithText(TextField, '00:30.000'), findsOneWidget);
    expect(find.text('/home/u/GIF'), findsOneWidget);
  });

  testWidgets('修改默认参数并保存 → SnackBar + 持久化', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    // 宽度选 480 px
    await tester.tap(find.text('原图等比').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('480 px').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置已保存'), findsOneWidget);
    final saved = jsonDecode(prefs.getString('default_gif_setting')!) as Map;
    expect(saved['width'], 480);
    expect(saved['fps'], 15.0, reason: '其余字段保持内置默认');
    expect(saved['scaleMultiplier'], 1.0, reason: '手动宽高 → 倍数归一 1.0');
  });

  testWidgets('选缩放倍数 2 倍 → 保存:倍数 2.0 + 宽高重置 0(入队逐文件展开)', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    // 选 2 倍(默认收起显示"1 倍")
    await tester.tap(find.text('1 倍'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 倍').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置已保存'), findsOneWidget);
    final saved = jsonDecode(prefs.getString('default_gif_setting')!) as Map;
    expect(saved['scaleMultiplier'], 2.0);
    expect(saved['width'], 0, reason: '选倍数 = 等比语义,宽高重置 0');
    expect(saved['height'], 0);
  });

  testWidgets('非法时间 → 红字 + 保存禁用;修正后恢复', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    // 开始时间框 = 第 2 个 TextField(循环/开始/结束);真实输入文本
    // 在 EditableText 内不渲染为 Text,须按类型+索引定位
    final startField = find.byType(TextField).at(1);
    await submitTime(tester, startField, 'abc');

    expect(find.text('开始时间格式非法(示例 00:03.200)'), findsOneWidget);
    var button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存设置'),
    );
    expect(button.onPressed, isNull, reason: 'formError 禁用保存');

    // 修正为合法时间 → 恢复可用
    await submitTime(tester, startField, '00:05.000');
    expect(find.text('开始时间格式非法(示例 00:03.200)'), findsNothing);
    button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存设置'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('主题切换:设置页内切深色 → 亮度变化', (tester) async {
    await pumpApp(tester);
    await enterSettings(tester);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(prefs.getString('theme_mode'), 'dark', reason: '主题持久化');
  });
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async {
    throw const SourceBrokenException(errorCode: 'GIF_1_SOURCE_BROKEN');
  }
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

class _FakeService implements FFmpegService {
  @override
  Future<ConvertResult> convertImages({
    required ImageGifSource source,
    required GifSetting setting,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    return convert(
      setting: setting,
      video: VideoInfo(
        path: source.paths.first,
        formatName: '',
        duration: Duration.zero,
        width: source.width,
        height: source.height,
        codec: '',
      ),
      taskId: taskId,
      workDir: workDir,
      outputPath: outputPath,
      cancelToken: cancelToken,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  @override
  Future<ConvertResult> convert({
    required GifSetting setting,
    required VideoInfo video,
    required int taskId,
    required String workDir,
    required String outputPath,
    CancelToken? cancelToken,
    void Function(TaskProgress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    await File(outputPath).writeAsBytes(List.filled(123, 1));
    return const ConvertResult(
      exitCode: 0,
      elapsed: Duration(seconds: 1),
      outputSizeBytes: 123,
    );
  }
}

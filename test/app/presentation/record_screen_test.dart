import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/app/presentation/preview_screen.dart';
import 'package:chameleon_gif/app/presentation/record_screen.dart';
import 'package:chameleon_gif/app/router.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/domain/entities/video_info.dart';
import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/parse_video_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';
import 'package:chameleon_gif/features/preview/application/preview_controller.dart';
import 'package:chameleon_gif/features/screen_record/application/region_picker.dart'
    show RegionGeometry, RegionPicker, screenRegionPickerProvider;
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_camera_port.dart';
import '../../fixtures/fake_ffmpeg_service.dart';
import '../../fixtures/fake_player_port.dart';
import '../../fixtures/fake_screen_recorder_port.dart';
import '../../fixtures/fake_settings_repository.dart';

/// [RecordScreen] 测试:敏感提示 / 开始录制编排 / 自动导入 / 错误语义。
///
/// 编排经 FakeScreenRecorderPort 注入(record 挂 Completer 模拟原生
/// 挂起 Result);停止按钮经 FakeScreenRecorderPort.requestStop 触发。
void main() {
  late Directory tempRoot;
  late FakeScreenRecorderPort recorderPort;
  late _MutableFakeRegionPicker regionPicker;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('record_screen_');
    recorderPort = FakeScreenRecorderPort();
    regionPicker = _MutableFakeRegionPicker();
    final adapter = _TestAdapter(tempRoot.path);
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appLoggerProvider.overrideWithValue(AppLogger()),
        screenRecorderPortProvider.overrideWithValue(recorderPort),
        cameraPortProvider.overrideWithValue(FakeCameraPort()),
        parseVideoPortProvider.overrideWithValue(_FakeParseVideoPort()),
        // 可变几何 fake 框选器(其余测试不点击框选按钮;回填用例改几何)
        screenRegionPickerProvider.overrideWithValue(regionPicker),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
        platformAdapterProvider.overrideWithValue(adapter),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        ffmpegServiceProvider.overrideWithValue(
          FakeFfmpegService(writeOutput: false),
        ),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: ref.read(ffmpegServiceProvider),
            platformAdapter: adapter,
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<void> pumpRecord(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ChameleonGifApp(
          router: GoRouter(
            routes: buildRoutes(),
            navigatorKey: rootNavigatorKey, // 自动导入 push 经此 key
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('屏幕录制'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordScreen), findsOneWidget);
  }

  testWidgets('启动即敏感内容确认横幅 + 开始按钮', (tester) async {
    await pumpRecord(tester);

    expect(find.textContaining('将录制屏幕内容'), findsOneWidget);
    expect(find.text('开始录制'), findsOneWidget);
  });

  testWidgets('桌面能力(无系统授权)→ 回放确认文案,无区域 UI', (tester) async {
    await pumpRecord(tester);
    expect(find.text('录制完成后自动导入工作台回放确认'), findsOneWidget);
    expect(find.text('录制区域'), findsNothing, reason: '无区域能力不显示');
  });

  testWidgets('Android 能力(requiresSystemConsent)→ 授权引导文案', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: true,
      requiresSystemConsent: true,
    );
    await pumpRecord(tester);
    expect(find.textContaining('每次录制需系统授权'), findsOneWidget);
    expect(find.text('录制区域'), findsNothing);
  });

  testWidgets('支持区域(gdigrab/x11grab)→ 区域选择 UI 显示', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: true,
      supportsRegions: true,
    );
    await pumpRecord(tester);
    expect(find.text('录制区域'), findsOneWidget);
    expect(find.text('全屏'), findsOneWidget);
    expect(find.text('自定义区域'), findsOneWidget);
  });

  testWidgets('区域切换:全屏 ↔ 自定义 即时反馈 + 持久化', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: true,
      supportsRegions: true,
    );
    await pumpRecord(tester);

    // 切到自定义:数字输入出现 + 仓储持久化
    await tester.tap(find.text('自定义区域'));
    await tester.pump();
    expect(find.text('起点 X'), findsOneWidget, reason: '自定义输入显示');
    expect(find.text('宽度'), findsOneWidget);
    final repo = container.read(settingsRepositoryProvider);
    expect(repo.recordParams?.regionMode, RecordRegion.custom);

    // 输入宽度:持久化生效
    await tester.enterText(find.widgetWithText(TextField, '宽度'), '640');
    await tester.pump();
    expect(repo.recordParams?.regionWidth, 640);

    // 切回全屏:输入隐藏
    await tester.tap(find.text('全屏'));
    await tester.pump();
    expect(find.text('起点 X'), findsNothing, reason: '全屏隐藏自定义输入');
    expect(repo.recordParams?.regionMode, RecordRegion.fullscreen);
  });

  testWidgets('重新进入:选区默认归零(清空上次框选并持久化)', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: true,
      supportsRegions: true,
    );
    final repo = container.read(settingsRepositoryProvider);
    await repo.setRecordParams(
      const RecordParams(
        regionMode: RecordRegion.custom,
        regionX: 60,
        regionY: 129,
        regionWidth: 678,
        regionHeight: 784,
      ),
    );
    await pumpRecord(tester);

    // 归零:自定义模式保留,但区域数值清空(输入框为空)且持久化
    expect(repo.recordParams?.regionMode, RecordRegion.custom);
    expect(repo.recordParams?.regionX, isNull);
    expect(repo.recordParams?.regionY, isNull);
    expect(repo.recordParams?.regionWidth, isNull);
    expect(repo.recordParams?.regionHeight, isNull);
    final xField = tester.widget<TextField>(
      find.widgetWithText(TextField, '起点 X'),
    );
    expect(xField.controller?.text, isEmpty, reason: '上次框选不残留');
  });

  testWidgets('拖拽框选成功 → 起点/宽高数值回填输入框', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: true,
      supportsRegions: true,
    );
    // 更新 fake 框选器几何(可变实例,override 不变)
    regionPicker.geometry = const RegionGeometry(
      x: 100,
      y: 200,
      width: 300,
      height: 400,
    );
    await pumpRecord(tester);

    await tester.tap(find.text('自定义区域'));
    await tester.pump();
    await tester.tap(find.text('框选录制范围'));
    await tester.pumpAndSettle();

    // 拖拽回填:输入框显示选区数值
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '起点 X'))
          .controller
          ?.text,
      '100',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '起点 Y'))
          .controller
          ?.text,
      '200',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '宽度'))
          .controller
          ?.text,
      '300',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '高度'))
          .controller
          ?.text,
      '400',
    );
  });

  testWidgets('录屏不可用 → 开始按钮禁用 + hint 文案', (tester) async {
    recorderPort.capabilities = const RecordCapabilities(
      screenCaptureAvailable: false,
      hint: '当前 Wayland 会话缺少屏幕共享支持',
    );
    // 首页入口已置灰(不可用),直接 pump 录制页验证页内态
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RecordScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('开始录制'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull, reason: '不可用禁用');
    expect(find.text('当前 Wayland 会话缺少屏幕共享支持'), findsOneWidget);
  });

  testWidgets('开始录制 → 录制中态(停止按钮 + 倒计时),收到仓储参数(挂起中)', (tester) async {
    final completer = Completer<CaptureResult>();
    recorderPort.onRecord = (params, token) => completer.future;
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pump();

    // 录制中态:停止按钮可点 + 倒计时渲染(record 挂起期间)
    final stopBtn = tester.widget<FilledButton>(
      find.ancestor(of: find.text('停止录制'), matching: find.byType(FilledButton)),
    );
    expect(stopBtn.onPressed, isNotNull, reason: '录制中显示可停止');
    expect(find.text('开始录制'), findsNothing);
    expect(find.textContaining(':'), findsWidgets, reason: '倒计时渲染');

    expect(recorderPort.recordCalls, hasLength(1));
    expect(recorderPort.recordCalls.single.fps, 15.0, reason: '仓储默认参数');
    expect(recorderPort.recordCalls.single.maxDurationMs, 0, reason: '默认不限时长');

    completer.complete(
      const CaptureResult(
        finalPath: '/tmp/captures/capture_1.mp4',
        durationMs: 1000,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('录制完成 → 自动导入 → /preview', (tester) async {
    final completer = Completer<CaptureResult>();
    recorderPort.onRecord = (params, token) => completer.future;
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pump();
    completer.complete(
      const CaptureResult(
        finalPath: '/tmp/captures/capture_1.mp4',
        durationMs: 1000,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PreviewScreen), findsOneWidget, reason: '自动导入推预览');
  });

  testWidgets('授权拒绝(CapturePermissionDeniedException)→ SnackBar 回 idle', (
    tester,
  ) async {
    recorderPort.onRecord = (params, token) async =>
        throw const CapturePermissionDeniedException(
          userMessage: '未获得录屏授权,已取消录制',
        );
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pumpAndSettle();

    expect(find.text('未获得录屏授权,已取消录制'), findsOneWidget);
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(find.text('开始录制'), findsOneWidget, reason: '回 idle 可重新发起');
  });

  testWidgets('取消(CaptureCancelledException)→ 静默', (tester) async {
    recorderPort.onRecord = (params, token) async =>
        throw const CaptureCancelledException();
    await pumpRecord(tester);

    await tester.tap(find.text('开始录制'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}

/// 可变几何的 fake 框选器(拖拽回填测试:测试内改 geometry)。
class _MutableFakeRegionPicker implements RegionPicker {
  RegionGeometry geometry = const RegionGeometry(
    x: 0,
    y: 0,
    width: 0,
    height: 0,
  );

  @override
  bool get isAvailable => true;

  @override
  Future<RegionGeometry?> pick() async => geometry;
}

class _FakeParseVideoPort implements ParseVideoPort {
  @override
  Future<VideoInfo> parse(String path) async => VideoInfo(
    path: path,
    formatName: 'mp4',
    duration: const Duration(seconds: 5),
    width: 640,
    height: 360,
    fps: 30,
    codec: 'h264',
  );
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

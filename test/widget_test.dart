import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/app/app.dart';
import 'package:chameleon_gif/core/logger/app_logger.dart';
import 'package:chameleon_gif/features/task_queue/application/task_manager.dart';
import 'package:chameleon_gif/features/task_queue/application/task_queue_providers.dart';
import 'package:chameleon_gif/shared/platform/platform_adapter.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_history_repository.dart';
import 'package:chameleon_gif/shared/repositories/in_memory_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/fake_camera_port.dart';
import 'fixtures/fake_ffmpeg_service.dart';

/// P0 冒烟:应用启动 → 渲染主页 → 主题切换生效且持久化。
///
/// 应用根已物化任务队列控制器(启动即崩溃恢复),依赖链必须完整 override:
/// taskManager → task/history 仓储 + ffmpeg 服务 + 平台适配。
void main() {
  late SharedPreferences prefs;
  late Directory tempRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempRoot = await Directory.systemTemp.createTemp('gifforge_widget_');
  });

  tearDown(() async {
    await tempRoot.delete(recursive: true);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        platformAdapterProvider.overrideWithValue(_TestAdapter(tempRoot.path)),
        cameraPortProvider.overrideWithValue(FakeCameraPort()),
        appDocsDirProvider.overrideWithValue(Directory(tempRoot.path)),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
        historyRepositoryProvider.overrideWithValue(
          InMemoryHistoryRepository(),
        ),
        taskManagerProvider.overrideWith(
          (ref) => TaskManager(
            taskRepository: ref.read(taskRepositoryProvider),
            historyRepository: ref.read(historyRepositoryProvider),
            ffmpegService: FakeFfmpegService(),
            platformAdapter: _TestAdapter(tempRoot.path),
            logger: AppLogger(),
            retryDelay: (_) async {},
          ),
        ),
      ],
      child: const ChameleonGifApp(),
    );
  }

  testWidgets('启动渲染主页,主题切换收敛于设置界面', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('Chameleon Gif'), findsWidgets);
    // 主题控件已从首页迁移至设置界面(负向断言防回归残留)
    expect(find.text('深色'), findsNothing);
    expect(find.byTooltip('设置'), findsOneWidget);

    // 进入设置界面切换主题
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsWidgets);

    // 切换到深色
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    // 切换到浅色
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
}

class _TestAdapter extends PlatformAdapter {
  _TestAdapter(this.tempRoot);

  final String tempRoot;

  @override
  String get systemTempDir => tempRoot;
}

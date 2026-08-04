import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/app/app.dart';
import 'package:gif_forge/app/application/providers.dart';
import 'package:gif_forge/app/router.dart';
import 'package:gif_forge/core/logger/app_logger.dart';
import 'package:gif_forge/domain/entities/video_info.dart';
import 'package:gif_forge/domain/exceptions/source_broken_exception.dart';
import 'package:gif_forge/domain/repository_interfaces/file_pick_port.dart';
import 'package:gif_forge/domain/repository_interfaces/parse_video_port.dart';
import 'package:gif_forge/features/import/application/import_providers.dart';
import 'package:gif_forge/features/preview/application/preview_controller.dart';
import 'package:gif_forge/features/preview/presentation/preview_page.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/fake_player_port.dart';

class _FakeFilePickPort implements FilePickPort {
  _FakeFilePickPort({this.path = '/tmp/videos/demo.mp4'});
  final String? path;

  @override
  Future<String?> pickMp4() async => path;
}

class _FakeParseVideoPort implements ParseVideoPort {
  _FakeParseVideoPort({this.onParse});

  final Future<VideoInfo> Function(String path)? onParse;

  @override
  Future<VideoInfo> parse(String path) {
    final handler = onParse;
    if (handler != null) return handler(path);
    return Future.value(
      VideoInfo(
        path: path,
        formatName: 'mp4',
        duration: const Duration(seconds: 5),
        width: 640,
        height: 360,
        fps: 30.0,
        codec: 'h264',
      ),
    );
  }
}

/// 主页导入入口链路:选文件 → 解析 → 跳转预览;异常 → SnackBar 中文文案。
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildApp({FilePickPort? filePickPort, ParseVideoPort? parsePort}) {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appLoggerProvider.overrideWithValue(AppLogger()),
        filePickPortProvider.overrideWithValue(
          filePickPort ?? _FakeFilePickPort(),
        ),
        parseVideoPortProvider.overrideWithValue(
          parsePort ?? _FakeParseVideoPort(),
        ),
        previewPlayerPortProvider.overrideWithValue(FakePlayerPort()),
      ],
      // 独立 router 实例:全局 appRouter 单例跨测试共享栈状态,会串扰
      child: GifForgeApp(router: GoRouter(routes: buildRoutes())),
    );
  }

  testWidgets('导入成功 → 跳转预览页(标题为文件名)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    expect(find.byType(PreviewPage), findsOneWidget);
    expect(find.text('demo.mp4'), findsOneWidget);
  });

  testWidgets('解析失败 → SnackBar 展示损坏文案,停留主页', (tester) async {
    await tester.pumpWidget(
      buildApp(
        parsePort: _FakeParseVideoPort(
          onParse: (_) => throw const SourceBrokenException(
            errorCode: 'GIF_1_SOURCE_BROKEN',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    expect(find.text('视频文件损坏或格式异常'), findsOneWidget);
    expect(find.byType(PreviewPage), findsNothing);
  });

  testWidgets('取消选择 → 无跳转无提示', (tester) async {
    await tester.pumpWidget(
      buildApp(filePickPort: _FakeFilePickPort(path: null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入 MP4'));
    await tester.pumpAndSettle();

    expect(find.byType(PreviewPage), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}

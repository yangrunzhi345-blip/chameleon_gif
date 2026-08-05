import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/entities/export_task.dart';
import 'package:chameleon_gif/domain/value_objects/gif_setting.dart';
import 'package:chameleon_gif/domain/value_objects/task_state.dart';
import 'package:chameleon_gif/features/export/presentation/export_complete_dialog.dart';
import 'package:chameleon_gif/shared/platform/gallery_save_result.dart';

/// [ExportCompleteDialog] 渲染与按钮测试(纯 UI,动作经 [ExportCompleteActions]
/// 注入,仅验证转发)。
void main() {
  final task = ExportTask(
    id: 1,
    videoPath: '/tmp/videos/demo.mp4',
    outputPath: '/tmp/gifforge_1/out.gif',
    settings: const GifSetting(),
    state: TaskState.completed,
    createdAt: DateTime(2026, 1, 1, 10),
    startedAt: DateTime(2026, 1, 1, 10, 0, 1),
    finishedAt: DateTime(2026, 1, 1, 10, 0, 5),
  );

  late int openCalls;
  late int shareCalls;
  late int resetCalls;

  Future<void> pump(WidgetTester tester, {ExportTask? taskOverride}) async {
    openCalls = 0;
    shareCalls = 0;
    resetCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ExportCompleteDialog(
                    task: taskOverride ?? task,
                    outputSizeBytes: 1536,
                    actions: ExportCompleteActions(
                      onOpen: () async => openCalls++,
                      onShare: () async => shareCalls++,
                      onReset: () async => resetCalls++,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('展示文件/大小/耗时', (tester) async {
    await pump(tester);

    expect(find.text('导出完成'), findsOneWidget);
    expect(find.textContaining('/tmp/gifforge_1/out.gif'), findsOneWidget);
    expect(find.text('大小:1.5 KB'), findsOneWidget);
    expect(find.text('耗时:4 秒'), findsOneWidget);
    expect(find.text('打开文件夹'), findsOneWidget);
    expect(find.text('再转一次'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('关闭按钮收起弹窗', (tester) async {
    await pump(tester);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
  });

  testWidgets('再转一次收起弹窗并复位', (tester) async {
    await pump(tester);

    await tester.tap(find.text('再转一次'));
    await tester.pumpAndSettle();

    expect(find.byType(ExportCompleteDialog), findsNothing);
    expect(resetCalls, 1, reason: '再转一次应复位会话');
  });

  testWidgets('打开文件夹转发到 onOpen 回调', (tester) async {
    await pump(tester);

    await tester.tap(find.text('打开文件夹'));
    await tester.pump();

    expect(openCalls, 1);
  });

  testWidgets('相册已保存 → 显示相册路径与"打开相册"', (tester) async {
    await pump(
      tester,
      taskOverride: ExportTask(
        id: 2,
        videoPath: '/tmp/videos/demo.mp4',
        outputPath: '/tmp/gifforge_2/out.gif',
        settings: const GifSetting(),
        state: TaskState.completed,
        createdAt: DateTime(2026, 1, 1, 10),
        galleryStatus: GallerySaveStatus.saved,
        galleryPath: 'Pictures/GIFForge/demo.gif',
        galleryUri: 'content://media/external/images/media/1',
      ),
    );

    expect(find.textContaining('已保存到系统相册'), findsOneWidget);
    expect(find.text('打开相册'), findsOneWidget);
  });

  testWidgets('相册保存失败 → 显示失败提示与"分享"', (tester) async {
    await pump(
      tester,
      taskOverride: ExportTask(
        id: 3,
        videoPath: '/tmp/videos/demo.mp4',
        outputPath: '/tmp/gifforge_3/out.gif',
        settings: const GifSetting(),
        state: TaskState.completed,
        createdAt: DateTime(2026, 1, 1, 10),
        galleryStatus: GallerySaveStatus.failed,
        galleryMessage: '系统版本过低,请使用系统分享保存',
      ),
    );

    expect(find.textContaining('未保存到相册'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);

    await tester.tap(find.text('分享'));
    await tester.pump();
    expect(shareCalls, 1);
  });
}

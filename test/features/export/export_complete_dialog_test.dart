import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gif_forge/domain/entities/export_task.dart';
import 'package:gif_forge/domain/value_objects/gif_setting.dart';
import 'package:gif_forge/domain/value_objects/task_state.dart';
import 'package:gif_forge/features/export/presentation/export_complete_dialog.dart';

/// [ExportCompleteDialog] 渲染与按钮测试(纯 UI)。
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ExportCompleteDialog(task: task, outputSizeBytes: 1536),
                  ),
                  child: const Text('open'),
                ),
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
}

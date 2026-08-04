import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chameleon_gif/domain/value_objects/task_progress.dart';
import 'package:chameleon_gif/features/export/application/export_providers.dart';
import 'package:chameleon_gif/features/export/presentation/export_progress_panel.dart';

/// [ExportProgressPanel] 渲染测试(override 进度流,纯 UI)。
void main() {
  Widget wrap(Stream<TaskProgress> stream) {
    return ProviderScope(
      overrides: [exportProgressProvider.overrideWith((ref) => stream)],
      child: const MaterialApp(home: Scaffold(body: ExportProgressPanel())),
    );
  }

  testWidgets('进度 50%:显示百分比与剩余时长,取消按钮存在', (tester) async {
    await tester.pumpWidget(
      wrap(
        Stream.value(
          TaskProgress(
            taskId: 1,
            percent: 0.5,
            elapsed: const Duration(seconds: 5),
            remaining: const Duration(seconds: 5),
          ),
        ),
      ),
    );

    await tester.pump(); // 等流事件派发
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('预计剩余 5 秒'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('无剩余数据(调色板遍):显示阶段文案', (tester) async {
    await tester.pumpWidget(
      wrap(
        Stream.value(
          TaskProgress(
            taskId: 1,
            percent: 0.0,
            elapsed: Duration.zero,
            remaining: null,
          ),
        ),
      ),
    );

    expect(find.text('正在生成调色板…'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('进度 100% 后取消按钮消失前仍可点击', (tester) async {
    await tester.pumpWidget(
      wrap(
        Stream.value(
          TaskProgress(
            taskId: 1,
            percent: 1.0,
            elapsed: const Duration(seconds: 10),
          ),
        ),
      ),
    );
    await tester.pump(); // 等流事件派发

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}

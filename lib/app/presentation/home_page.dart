import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/exceptions/file_pick_exception.dart';
import '../../domain/value_objects/app_theme_mode.dart';
import '../../features/import/application/import_providers.dart';
import '../application/providers.dart';

/// 主页(P0 占位 + P2 导入入口):验证 初始化→路由→主题→导入 链路。
///
/// 转换工作台(时间轴/参数)由 P4 阶段组装,见 docs/10-UI设计.md §10.3.1。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// 选文件 → 解析 → 跳预览;取消静默,异常以 SnackBar 展示中文文案。
  Future<void> _importAndPreview(BuildContext context, WidgetRef ref) async {
    final path = await ref.read(filePickPortProvider).pickMp4();
    if (path == null || !context.mounted) return;
    try {
      final info = await ref.read(importVideoUseCaseProvider).execute(path);
      if (!context.mounted) return;
      context.push('/preview', extra: info);
    } on FilePickException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  /// 批量导入(P6-WP1):多选 → 跳批量导入设置页(无预览,参数装配后入队)。
  Future<void> _batchImport(BuildContext context, WidgetRef ref) async {
    final paths = await ref.read(filePickPortProvider).pickMp4s();
    if (paths == null || paths.isEmpty || !context.mounted) return;
    context.push('/batch-import', extra: paths);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chameleon Gif'),
        actions: [
          IconButton(
            tooltip: '队列',
            icon: const Icon(Icons.queue),
            onPressed: () => context.push('/queue'),
          ),
          IconButton(
            tooltip: '历史',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gif_box_outlined, size: 96),
            const SizedBox(height: 16),
            const Text(
              'Chameleon Gif',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('基础架构就绪 · 主题:${themeMode.name}'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _importAndPreview(context, ref),
              icon: const Icon(Icons.movie_outlined),
              label: const Text('导入 MP4'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _batchImport(context, ref),
              icon: const Icon(Icons.playlist_add),
              label: const Text('批量导入'),
            ),
            const SizedBox(height: 24),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('深色'),
                ),
                ButtonSegment(
                  value: AppThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('跟随系统'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

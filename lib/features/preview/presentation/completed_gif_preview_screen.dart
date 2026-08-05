import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/video_info.dart';
import '../application/gif_preview_controller.dart';
import '../application/preview_providers.dart';
import 'gif_preview_panel.dart';

/// 预览完成 GIF 页(批量完成弹窗"预览"入口,任务 4 新增)。
///
/// 左侧本批次已完成的 GIF 列表(点击切换),右侧 [GifPreviewPanel] +
/// [GifControlsBar];播放走 [GifPreviewController](image 包逐帧解码,
/// Android mpv 无法播放 GIF 的替代,全平台一致)。
/// 路由 extra: `List<String>` 输出路径;非法(恢复/深链)或空 → 回退返回。
class CompletedGifPreviewScreen extends ConsumerStatefulWidget {
  const CompletedGifPreviewScreen({super.key, this.paths});

  /// 已完成的 GIF 输出路径列表(经路由 extra 传入)。
  final List<String>? paths;

  @override
  ConsumerState<CompletedGifPreviewScreen> createState() =>
      _CompletedGifPreviewScreenState();
}

class _CompletedGifPreviewScreenState
    extends ConsumerState<CompletedGifPreviewScreen> {
  @override
  void initState() {
    super.initState();
    final paths = widget.paths;
    // 恢复/深链下 extra 非法或为空 → 回退返回(镜像 preview_screen 范式)
    Future.microtask(() {
      if (!mounted) return;
      if (paths == null || paths.isEmpty) {
        context.pop();
        return;
      }
      _select(paths.first);
    });
  }

  /// 构造最小 VideoInfo:播放仅依赖 path([GifPreviewController.load] 只用
  /// video.path),其余字段空值直给,不做 ffprobe。
  VideoInfo _gifInfo(String path) => VideoInfo(
    path: path,
    formatName: 'gif',
    duration: Duration.zero,
    width: 0,
    height: 0,
    codec: 'gif',
  );

  /// 切换播放:同一控制器重新 load(loading → ready,自动播放)。
  void _select(String path) {
    ref.read(gifPreviewControllerProvider.notifier).load(_gifInfo(path));
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(gifPreviewControllerProvider).video?.path;
    final paths = widget.paths ?? const <String>[];

    final list = ListView.builder(
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        final name = path.split(RegExp(r'[\\/]')).last;
        return ListTile(
          dense: true,
          selected: path == current,
          title: Text(name, overflow: TextOverflow.ellipsis),
          onTap: () => _select(path),
        );
      },
    );
    final player = Column(
      children: [
        Expanded(child: Center(child: GifPreviewPanel())),
        SafeArea(child: GifControlsBar()),
      ],
    );

    // 宽屏左右分栏,窄屏上下排
    return Scaffold(
      appBar: AppBar(title: const Text('预览完成 GIF')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                SizedBox(width: 280, child: list),
                const VerticalDivider(width: 1),
                Expanded(child: player),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(height: 160, child: list),
              const Divider(height: 1),
              Expanded(child: player),
            ],
          );
        },
      ),
    );
  }
}

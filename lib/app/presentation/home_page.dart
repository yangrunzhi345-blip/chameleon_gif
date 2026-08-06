import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/import/application/import_providers.dart';
import 'import_actions.dart';

/// 主页:品牌区 + 功能入口(图片制作 GIF / 导入 MP4 / 批量导入 /
/// 批量导入设置),右上快捷入口(队列/历史/设置)。
/// 转换工作台(时间轴/参数)在预览页,见 docs/10-UI设计.md §10.3.1。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// 批量导入(P6-WP1):多选 → 跳批量导入设置页(无预览,参数装配后入队)。
  Future<void> _batchImport(BuildContext context, WidgetRef ref) async {
    final paths = await ref.read(filePickPortProvider).pickMp4s();
    if (paths == null || paths.isEmpty || !context.mounted) return;
    context.push('/batch-import', extra: paths);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 采集入口平台态(渲染决策,UI 层判定):Android 常亮,桌面置灰
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(
        // ellipsis:窄窗口下标题截断,避免与 3 个快捷入口 IconButton
        // 叠加溢出(真机实测窄窗口溢出 119px;AppBar title slot 非 Flex,
        // 不能用 Flexible 包裹)
        title: const Text(
          'Chameleon Gif',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      // Center 包裹:Column 水平宽度收缩到最宽子元素(非 stretch),
      // 直接作 body 子级会被放在左上角导致内容偏左(实测偏左 26dp);
      // Center 让其以屏幕中线对齐。
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 品牌区:Logo + 应用名 + 标语,整体上移(顶部留白 24;
            // 视频来源组两按钮加入后收窄顶部留白防溢出)
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/chameleon.jpg',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chameleon Gif',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('基础架构就绪', textAlign: TextAlign.center),
            // 按钮区下沉到底部
            const Spacer(),
            // 视频来源组:相机拍摄 / 屏幕录制(Android 常亮;桌面置灰 +
            // tooltip,采集能力属平台态,UI 层 defaultTargetPlatform 判定)
            Row(
              children: [
                Expanded(
                  child: _SourceEntry(
                    icon: Icons.photo_camera_outlined,
                    label: '相机拍摄',
                    subtitle: '拍一段→转GIF',
                    enabled: isAndroid,
                    tooltip: '未检测到摄像头(桌面采集将在后续版本开放)',
                    onPressed: () => openCaptureScreen(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceEntry(
                    icon: Icons.screen_share_outlined,
                    label: '屏幕录制',
                    subtitle: '录一段→转GIF',
                    enabled: isAndroid,
                    tooltip: '桌面采集将在后续版本开放',
                    onPressed: () => openRecordScreen(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 图片制作 GIF:入口位于「导入 MP4」上方,样式一致
            FilledButton.icon(
              onPressed: () => pickImagesAndBuild(context, ref),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('图片制作 GIF'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => pickMp4AndPreview(context, ref),
              icon: const Icon(Icons.movie_outlined),
              label: const Text('导入 MP4'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _batchImport(context, ref),
              icon: const Icon(Icons.playlist_add),
              label: const Text('批量导入'),
            ),
            const SizedBox(height: 8),
            // 批量导入默认参数设置(直接进设置界面,返回回首页)
            TextButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('批量导入设置'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// 视频来源组入口(相机拍摄/屏幕录制;docs/18 §五、docs/19 §三)。
///
/// [enabled] 为 false 时按钮置灰 + tooltip(平台能力不足,不隐藏,
/// 环境变化后恢复);点击动作由 [onPressed] 提供(入口保持单一动作)。
class _SourceEntry extends StatelessWidget {
  const _SourceEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    if (enabled) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

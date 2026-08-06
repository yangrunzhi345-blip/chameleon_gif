import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/duration_format.dart';
import '../../features/import/application/import_providers.dart';
import '../application/batch_import_controller.dart';
import '../application/batch_import_state.dart';
import 'batch_parameter_form.dart';

/// 批量导入页(app 层跨模块组合壳;与预览页的区别:无视频预览、
/// 无时间轴)。
///
/// 左栏文件列表(可移除单个/重新选择,页面本地状态),右栏**当前默认
/// 参数摘要**(只读,来源持久化默认)+"批量导入设置"入口(进设置界面
/// 改默认,返回时回到本页);点"开始批量转换"后经
/// [BatchImportController.start] 以默认参数逐文件解析入队,成功跳队列页。
/// extra 为 null(恢复/深链)时立即回退返回;空列表停留空态(完成弹窗
/// "返回批量导入"经空 extra 进入),由"重新选择视频"入口补充文件。
class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key, required this.paths});

  /// 已选文件路径列表(经路由 extra 传入;null 由壳在 initState 回退)。
  final List<String>? paths;

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  /// 右侧控制面板靠上对齐的高度阈值:右栏 maxHeight >= 此值视为
  /// 全屏/大窗口(面板加 Spacer 顶到顶部);否则保持原布局。
  static const double _outputPanelTopThreshold = 800;

  /// 页面本地文件列表(路由 extra 复制为可变副本,移除仅 UI 交互)。
  late List<String> _paths;

  @override
  void initState() {
    super.initState();
    final paths = widget.paths;
    // 纯字段初始化须在 initState 同步完成(首次 build 先于 microtask)
    _paths = paths == null ? [] : [...paths];
    // 仅 extra 非 List<String>(恢复/深链)时回退返回;空列表停留空态,
    // 表单照常 init(重置为持久化默认,恢复初始语义)
    Future.microtask(() {
      if (!mounted) return;
      if (paths == null) {
        context.pop();
        return;
      }
      ref.read(batchImportControllerProvider.notifier).init();
    });
  }

  void _removePath(int index) {
    setState(() => _paths.removeAt(index));
  }

  /// 重新选择/追加视频文件(空态下的唯一入口,恢复初始后可继续导入)。
  Future<void> _pickMore() async {
    final picked = await ref.read(importVideoUseCaseProvider).pickVideoFiles();
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _paths = [..._paths, ...picked]);
  }

  /// 开始批量转换:校验通过 → 入队 → 提示/跳转队列页。
  Future<void> _startBatch() async {
    final result = await ref
        .read(batchImportControllerProvider.notifier)
        .start(_paths);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.enqueued == 0) {
      // start>=end 校验失败(formError 已红字)不提示;真失败才提示
      final failed = result.failed > 0;
      if (failed) {
        messenger.showSnackBar(const SnackBar(content: Text('批量导入失败,请检查文件')));
      }
      return; // 不跳转
    }
    if (result.failed > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('已入队 ${result.enqueued} 个,跳过 ${result.failed} 个'),
        ),
      );
    }
    context.push('/queue');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchImportControllerProvider);

    final fileList = _FileListPanel(
      paths: _paths,
      onRemove: _removePath,
      onPickMore: _pickMore,
    );
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('批量导入默认参数'),
          _DefaultSummary(state: state),
          const SizedBox(height: 8),
          // 进设置界面改默认参数;返回时回到本页(栈式导航)
          OutlinedButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('批量导入设置'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_paths.isEmpty || state.formError != null)
                ? null
                : _startBatch,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('开始批量转换'),
          ),
          if (_paths.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '文件列表为空,请点击"重新选择视频"添加文件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );

    // 输出控制面板封装(内容不变,仅由壳按右栏高度自适应布局排列)
    final panel = _OutputControlPanel(child: form);

    // 全屏/大窗口判定:与 body 右栏同一阈值(窗口高 ≈ 右栏高 + AppBar 高,
    // 桌面端无系统栏裁剪;AppBar 贴顶不悬浮,两栏满铺无空隙)
    final largeWindow =
        MediaQuery.sizeOf(context).height >=
        _outputPanelTopThreshold + kToolbarHeight;

    // 双栏:宽屏左文件列表右表单;窄屏上下排
    return Scaffold(
      // 全屏/大窗口:顶部 AppBar 同样加主题色 1px 边框 + 圆角,
      // 贴顶满铺不悬浮(无白色空隙);窄屏保持默认无边框
      appBar: AppBar(
        title: const Text('批量导入'),
        shape: largeWindow
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                // 左栏文件列表卡片:全屏/大窗口加主题色 1px 边框 + 圆角,
                // 满铺无空隙;半屏/小窗口保持原布局
                Expanded(
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxHeight >= _outputPanelTopThreshold) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: fileList,
                          );
                        }
                        return fileList;
                      },
                    ),
                  ),
                ),
                // 右栏参数表单卡片(同左栏;Material 背景同步圆角防溢出,
                // 边框已承担分隔,不再加 divider)
                SizedBox(
                  width: 360,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 全屏/大窗口(右栏高 >= 阈值):面板靠上对齐,
                        // Spacer 占据下方剩余空间
                        if (constraints.maxHeight >= _outputPanelTopThreshold) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              child: Column(children: [panel, const Spacer()]),
                            ),
                          );
                        }
                        // 半屏/小窗口:保持原有布局(仅面板,不加 Spacer)
                        return ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: Column(children: [panel]),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: fileList),
              const Divider(height: 1),
              Flexible(child: form),
            ],
          );
        },
      ),
    );
  }
}

/// 输出控制面板封装:仅承载现有参数表单内容(保持不变,不做任何修改),
/// 布局排列(大窗口 Column+Spacer 靠上 / 小窗口仅面板)由壳在
/// LayoutBuilder 中按右栏高度决定。
class _OutputControlPanel extends StatelessWidget {
  const _OutputControlPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// 当前默认参数只读摘要(数据来自 init 后的表单状态,纯展示)。
class _DefaultSummary extends StatelessWidget {
  const _DefaultSummary({required this.state});

  final BatchImportFormState state;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final size = (state.width == 0 && state.height == 0)
        ? '原图等比'
        : '${state.width}×${state.height}';
    final loop = state.loop == 0 ? '无限循环' : '循环 ${state.loop}';
    final range = state.end == null
        ? '全长'
        : '到 ${formatFfmpegTime(state.end!)}';
    final dir = state.outputDir ?? '系统临时目录(默认)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${state.fps.toInt()} fps · $size · $loop · $range',
            style: style,
          ),
          const SizedBox(height: 4),
          Text('导出目录:$dir', style: style),
        ],
      ),
    );
  }
}

/// 已选文件列表面板(纯渲染;移除/重新选择回调由壳 setState 处理)。
class _FileListPanel extends StatelessWidget {
  const _FileListPanel({
    required this.paths,
    required this.onRemove,
    required this.onPickMore,
  });

  final List<String> paths;
  final void Function(int index) onRemove;
  final VoidCallback onPickMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '已选 ${paths.length} 个文件',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // 重新选择/追加文件(空态下也可用,恢复初始后继续导入)
              TextButton.icon(
                onPressed: onPickMore,
                icon: const Icon(Icons.video_library_outlined, size: 18),
                label: const Text('重新选择视频'),
              ),
            ],
          ),
        ),
        Expanded(
          child: paths.isEmpty
              ? const Center(child: Text('文件列表为空'))
              : ListView.separated(
                  itemCount: paths.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final name = paths[index]
                        .split(RegExp(r'[\\/]'))
                        .last; // Windows 反斜杠兼容(纯字符串处理)
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.movie_outlined),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: '移除',
                        icon: const Icon(Icons.close),
                        onPressed: () => onRemove(index),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

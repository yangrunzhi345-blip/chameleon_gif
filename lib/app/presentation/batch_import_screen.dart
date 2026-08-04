import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/batch_import_controller.dart';
import 'batch_parameter_form.dart';

/// 批量导入设置页(app 层跨模块组合壳;与预览页的区别:无视频预览、
/// 无时间轴)。
///
/// 左栏文件列表(可移除单个,页面本地状态),右栏完整参数表单
/// (公共组件 [BatchParameterForm]);点"开始批量转换"后经
/// [BatchImportController.start] 逐文件解析入队,成功跳队列页。
/// extra 非 List\<String\>(恢复/深链)或为空时立即回退返回。
class BatchImportScreen extends ConsumerStatefulWidget {
  const BatchImportScreen({super.key, required this.paths});

  /// 已选文件路径列表(经路由 extra 传入;null 由壳在 initState 回退)。
  final List<String>? paths;

  @override
  ConsumerState<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends ConsumerState<BatchImportScreen> {
  /// 页面本地文件列表(路由 extra 复制为可变副本,移除仅 UI 交互)。
  late List<String> _paths;

  @override
  void initState() {
    super.initState();
    final paths = widget.paths;
    // 纯字段初始化须在 initState 同步完成(首次 build 先于 microtask)
    _paths = paths == null ? [] : [...paths];
    // 恢复/深链路径下 extra 非 List<String> 或为空 → 回退返回
    Future.microtask(() {
      if (!mounted) return;
      if (paths == null || paths.isEmpty) {
        context.pop();
        return;
      }
      ref.read(batchImportControllerProvider.notifier).init();
    });
  }

  void _removePath(int index) {
    setState(() => _paths.removeAt(index));
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
    final controller = ref.read(batchImportControllerProvider.notifier);

    final fileList = _FileListPanel(paths: _paths, onRemove: _removePath);
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BatchParameterForm(state: state, actions: controller),
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
                '文件列表为空,请返回重新选择',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );

    // 双栏:宽屏左文件列表右表单;窄屏上下排
    return Scaffold(
      appBar: AppBar(title: const Text('批量导入设置')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                Expanded(child: fileList),
                SizedBox(
                  width: 360,
                  child: SafeArea(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: form,
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

/// 已选文件列表面板(纯渲染;移除回调由壳 setState 处理)。
class _FileListPanel extends StatelessWidget {
  const _FileListPanel({required this.paths, required this.onRemove});

  final List<String> paths;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '已选 ${paths.length} 个文件',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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

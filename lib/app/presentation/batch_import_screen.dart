import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/duration_format.dart';
import '../../features/export/presentation/param_dropdown_field.dart';
import '../application/batch_import_controller.dart';
import '../application/batch_import_state.dart';

/// 批量导入设置页(app 层跨模块组合壳;与预览页的区别:无视频预览、
/// 无时间轴)。
///
/// 左栏文件列表(可移除单个,页面本地状态),右栏完整参数表单
/// (帧率/宽高/循环/起止时间/导出目录);点"开始批量转换"后经
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
  final _loopCtrl = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  bool _loopFocused = false;
  bool _startFocused = false;
  bool _endFocused = false;

  /// 页面本地文件列表(路由 extra 复制为可变副本,移除仅 UI 交互)。
  late List<String> _paths;

  static const _fpsOptions = [
    8.0,
    10.0,
    12.0,
    15.0,
    20.0,
    24.0,
    30.0,
    50.0,
    60.0,
  ];
  static const _widthOptions = [
    0,
    240,
    320,
    480,
    640,
    720,
    960,
    1080,
    1280,
    1920,
  ];

  /// 面板输入控件统一边框(与 ParamDropdownField 收起态一致)。
  static const _kInputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

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

  @override
  void dispose() {
    _loopCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _removePath(int index) {
    setState(() => _paths.removeAt(index));
  }

  /// 未聚焦时从 state 回填文本(参数变更后文本随之刷新)。
  void _syncTextFields(BatchImportFormState state) {
    if (!_loopFocused) _loopCtrl.text = '${state.loop}';
    if (!_startFocused) _startCtrl.text = _formatTimeInput(state.start);
    if (!_endFocused) {
      _endCtrl.text = state.end == null ? '' : _formatTimeInput(state.end!);
    }
  }

  String _formatTimeInput(Duration d) {
    final total = d.inMilliseconds;
    final m = (total ~/ 60000).toString().padLeft(2, '0');
    final s = ((total % 60000) / 1000).toStringAsFixed(3).padLeft(6, '0');
    return '$m:$s';
  }

  void _submitStart(String text) {
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      ref
          .read(batchImportControllerProvider.notifier)
          .updateFormError('开始时间格式非法(示例 00:03.200)');
      return;
    }
    ref.read(batchImportControllerProvider.notifier).updateStart(parsed);
  }

  void _submitEnd(String text) {
    if (text.trim().isEmpty) {
      ref.read(batchImportControllerProvider.notifier).updateEnd(null);
      return;
    }
    final parsed = parseFfmpegTime(text);
    if (parsed == null) {
      ref
          .read(batchImportControllerProvider.notifier)
          .updateFormError('结束时间格式非法(示例 00:09.500)');
      return;
    }
    ref.read(batchImportControllerProvider.notifier).updateEnd(parsed);
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
    _syncTextFields(state);
    final controller = ref.read(batchImportControllerProvider.notifier);
    final formError = state.formError;

    final fileList = _FileListPanel(paths: _paths, onRemove: _removePath);
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('输出'),
          _ParamRow(
            label: '帧率',
            child: ParamDropdownField<double>(
              value: state.fps,
              items: [
                for (final fps in _fpsOptions)
                  ParamDropdownItem(fps, '${fps.toInt()} fps'),
              ],
              onChanged: controller.updateFps,
            ),
          ),
          _ParamRow(
            label: '宽度',
            child: ParamDropdownField<int>(
              value: state.width,
              items: [
                for (final w in _widthOptions)
                  ParamDropdownItem(w, w == 0 ? '原图等比' : '$w px'),
              ],
              onChanged: controller.updateWidth,
            ),
          ),
          _ParamRow(
            label: '高度',
            child: ParamDropdownField<int>(
              value: state.height,
              items: [
                for (final h in _widthOptions)
                  ParamDropdownItem(h, h == 0 ? '原图等比' : '$h px'),
              ],
              onChanged: controller.updateHeight,
            ),
          ),
          _ParamRow(
            label: '循环',
            child: TextField(
              controller: _loopCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0 = 无限循环',
                border: _kInputBorder,
              ),
              onChanged: (_) => _loopFocused = true,
              onTap: () => _loopFocused = true,
              onSubmitted: (text) {
                _loopFocused = false;
                final v = int.tryParse(text.trim());
                if (v == null) {
                  controller.updateFormError('循环次数须为数字');
                } else {
                  controller.updateLoop(v);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('时间'),
          _ParamRow(
            label: '开始',
            child: TextField(
              controller: _startCtrl,
              decoration: const InputDecoration(
                hintText: '00:00.000',
                border: _kInputBorder,
              ),
              onChanged: (_) => _startFocused = true,
              onTap: () => _startFocused = true,
              onSubmitted: (text) {
                _startFocused = false;
                _submitStart(text);
              },
            ),
          ),
          _ParamRow(
            label: '结束',
            child: TextField(
              controller: _endCtrl,
              decoration: const InputDecoration(
                hintText: '留空 = 到结尾',
                border: _kInputBorder,
              ),
              onChanged: (_) => _endFocused = true,
              onTap: () => _endFocused = true,
              onSubmitted: (text) {
                _endFocused = false;
                _submitEnd(text);
              },
            ),
          ),
          if (formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                formError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          const _SectionLabel('目录'),
          Row(
            children: [
              Expanded(
                child: Text(
                  state.outputDir ?? '系统临时目录(默认)',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: controller.pickOutputDir,
                child: const Text('选择目录'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_paths.isEmpty || formError != null)
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

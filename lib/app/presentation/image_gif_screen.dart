import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/duration_format.dart';
import '../../features/export/presentation/export_complete_dialog.dart';
import '../../features/export/presentation/param_dropdown_field.dart';
import '../../features/import/application/import_providers.dart';
import '../application/image_gif_controller.dart';
import '../application/image_gif_state.dart';
import 'batch_parameter_form.dart' show ParamRow, SectionLabel;

/// 图片制作 GIF 页(app 层组合壳,仿 batch_import_screen 模式)。
///
/// 经路由 extra 接收有序图片路径列表;extra 为空(回退/深链)立即返回主页。
/// 左栏:图片列表(缩略图 + 上移/下移/删除/追加);右栏:参数表单(帧率/
/// 每图停留时长/宽高/循环/质量/目录,无时间裁剪);底部转换按钮入队。
/// 完成弹窗/失败提示经生命周期监听触发(与 preview_screen 同模式)。
class ImageGifScreen extends ConsumerStatefulWidget {
  const ImageGifScreen({super.key, required this.paths});

  final List<String>? paths;

  @override
  ConsumerState<ImageGifScreen> createState() => _ImageGifScreenState();
}

class _ImageGifScreenState extends ConsumerState<ImageGifScreen> {
  /// 右侧控制面板靠上对齐的高度阈值:右栏 maxHeight >= 此值视为
  /// 全屏/大窗口(面板加 Spacer 顶到顶部);否则保持原布局。
  static const double _outputPanelTopThreshold = 800;

  late List<String> _paths = [];
  final _frameDurationCtrl = TextEditingController();
  final _loopCtrl = TextEditingController();
  bool _frameDurationFocused = false;
  bool _loopFocused = false;

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
  static const _sizeOptions = [
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

  static const _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后初始化:避免 initState 内触发 Notifier 状态写入
    Future.microtask(() {
      if (!mounted) return;
      final paths = widget.paths;
      if (paths == null || paths.isEmpty) {
        context.pop();
        return;
      }
      _paths = List.of(paths);
      ref.read(imageGifControllerProvider.notifier).init();
    });
    // 生命周期监听:完成 → 弹窗;失败/取消 → SnackBar(initState 用 listenManual)
    ref.listenManual<ImageGifFormState>(imageGifControllerProvider, (_, state) {
      if (!mounted) return;
      switch (state.lifecycle) {
        case ImageGifLifecycle.done:
          final task = state.task;
          if (task != null) {
            final notifier = ref.read(imageGifControllerProvider.notifier);
            showDialog<void>(
              context: context,
              builder: (_) => ExportCompleteDialog(
                task: task,
                outputSizeBytes: state.outputSizeBytes ?? 0,
                actions: ExportCompleteActions(
                  onOpen: notifier.openOutputFolder,
                  onShare: notifier.shareGif,
                  onReset: notifier.reset,
                ),
              ),
            );
          }
        case ImageGifLifecycle.failed:
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? '转换失败')),
            );
        case ImageGifLifecycle.idle:
        case ImageGifLifecycle.exporting:
          break;
      }
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _frameDurationCtrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  Future<void> _appendImages() async {
    final more = await ref.read(filePickPortProvider).pickImages();
    if (more == null || more.isEmpty || !mounted) return;
    setState(() {
      _paths = [..._paths, ...more];
    });
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final tmp = _paths[index - 1];
      _paths[index - 1] = _paths[index];
      _paths[index] = tmp;
    });
  }

  void _moveDown(int index) {
    if (index >= _paths.length - 1) return;
    setState(() {
      final tmp = _paths[index + 1];
      _paths[index + 1] = _paths[index];
      _paths[index] = tmp;
    });
  }

  void _removeAt(int index) {
    setState(() {
      _paths.removeAt(index);
    });
  }

  void _syncTextFields(ImageGifFormState state) {
    if (!_frameDurationFocused) {
      _frameDurationCtrl.text = '${state.frameDurationMs}';
    }
    if (!_loopFocused) _loopCtrl.text = '${state.loop}';
  }

  void _submitFrameDuration(String text) {
    _frameDurationFocused = false;
    final v = int.tryParse(text.trim());
    if (v == null) {
      ref
          .read(imageGifControllerProvider.notifier)
          .updateFormError('每张图片停留时长须为数字(毫秒)');
      return;
    }
    ref.read(imageGifControllerProvider.notifier).updateFrameDurationMs(v);
  }

  void _submitLoop(String text) {
    _loopFocused = false;
    final v = int.tryParse(text.trim());
    if (v == null) {
      ref.read(imageGifControllerProvider.notifier).updateFormError('循环次数须为数字');
      return;
    }
    ref.read(imageGifControllerProvider.notifier).updateLoop(v);
  }

  Future<void> _startConvert() async {
    final notifier = ref.read(imageGifControllerProvider.notifier);
    await notifier.submit(List.of(_paths));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGifControllerProvider);
    final notifier = ref.read(imageGifControllerProvider.notifier);
    _syncTextFields(state);
    final exporting = state.locked;
    final total = Duration(milliseconds: state.frameDurationMs * _paths.length);

    final listPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('图片顺序(${_paths.length} 张)'),
        Flexible(
          child: _paths.isEmpty
              ? const Center(child: Text('尚未选择图片'))
              : ListView.builder(
                  itemCount: _paths.length,
                  itemBuilder: (context, i) {
                    final path = _paths[i];
                    final name = path.split(RegExp(r'[\\/]')).last;
                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(path),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('第 ${i + 1} 张'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 下移在左、上移在右(末项禁用)
                          IconButton(
                            tooltip: '下移',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: i < _paths.length - 1
                                ? () => _moveDown(i)
                                : null,
                          ),
                          IconButton(
                            tooltip: '上移',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: i > 0 ? () => _moveUp(i) : null,
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.close),
                            onPressed: exporting ? null : () => _removeAt(i),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '共 ${_paths.length} 张 · 每张 ${state.frameDurationMs} ms · 总时长 ${formatHumanDuration(total)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: exporting ? null : _appendImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('追加图片'),
            ),
          ],
        ),
      ],
    );

    final formPanel = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('输出'),
          ParamRow(
            label: '帧率',
            child: ParamDropdownField<double>(
              value: state.fps,
              items: [
                for (final fps in _fpsOptions)
                  ParamDropdownItem(fps, '${fps.toInt()} fps'),
              ],
              onChanged: notifier.updateFps,
              enabled: !exporting,
            ),
          ),
          ParamRow(
            label: '每图时长',
            child: TextField(
              controller: _frameDurationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                // 常显单位(默认 1000 是毫秒,无单位提示易误读为秒)
                suffixText: '毫秒',
                hintText: '如 1000',
                border: _inputBorder,
              ),
              onChanged: (_) => _frameDurationFocused = true,
              onTap: () => _frameDurationFocused = true,
              onSubmitted: _submitFrameDuration,
            ),
          ),
          ParamRow(
            label: '宽度',
            child: ParamDropdownField<int>(
              value: state.width,
              items: [
                for (final w in _sizeOptions)
                  ParamDropdownItem(w, w == 0 ? '原图等比' : '$w px'),
              ],
              onChanged: notifier.updateWidth,
              enabled: !exporting,
            ),
          ),
          ParamRow(
            label: '高度',
            child: ParamDropdownField<int>(
              value: state.height,
              items: [
                for (final h in _sizeOptions)
                  ParamDropdownItem(h, h == 0 ? '原图等比' : '$h px'),
              ],
              onChanged: notifier.updateHeight,
              enabled: !exporting,
            ),
          ),
          ParamRow(
            label: '循环',
            child: TextField(
              controller: _loopCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0 = 无限循环',
                border: _inputBorder,
              ),
              onChanged: (_) => _loopFocused = true,
              onTap: () => _loopFocused = true,
              onSubmitted: _submitLoop,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('高质量(调色板两遍)'),
            value: state.usePalette,
            onChanged: exporting ? null : notifier.updateUsePalette,
          ),
          if (state.formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                state.formError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          const SectionLabel('目录'),
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
                onPressed: exporting ? null : notifier.pickOutputDir,
                child: const Text('选择目录'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _paths.isEmpty || state.formError != null || exporting
                ? null
                : _startConvert,
            icon: Icon(exporting ? Icons.hourglass_top : Icons.animation),
            label: Text(exporting ? '转换中…' : '开始转换'),
          ),
        ],
      ),
    );

    // 输出控制面板封装(内容不变,仅由壳按右栏高度自适应布局排列)
    final panel = _OutputControlPanel(child: formPanel);

    // 全屏/大窗口判定:与 body 右栏同一阈值(窗口高 ≈ 右栏高 + AppBar 高,
    // 桌面端无系统栏裁剪;AppBar 贴顶不悬浮,两栏满铺无空隙)
    final largeWindow =
        MediaQuery.sizeOf(context).height >=
        _outputPanelTopThreshold + kToolbarHeight;

    return Scaffold(
      // 全屏/大窗口:顶部 AppBar(返回首页按钮区)同样加主题色 1px
      // 边框 + 圆角,贴顶满铺不悬浮(无白色空隙);窄屏保持默认无边框
      appBar: AppBar(
        title: const Text('图片制作 GIF'),
        leading: BackButton(onPressed: () => context.pop()),
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
                SizedBox(
                  width: 380,
                  child: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 全屏/大窗口:图片顺序区加主题色 1px 边框 + 圆角
                        // (与右栏面板同一高度阈值判定)
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
                            child: listPanel,
                          );
                        }
                        // 半屏/小窗口:保持原有布局(无边框)
                        return listPanel;
                      },
                    ),
                  ),
                ),
                // 卡片自身边框已承担分隔,不再加 divider(避免叠成 3px 粗线)
                Expanded(
                  child: SafeArea(
                    // Material 而非 ColoredBox:SwitchListTile 的 ink 需
                    // Material 祖先,ColoredBox 会隐藏波纹并触发框架断言
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 全屏/大窗口:右栏与左栏一致,加主题色 1px
                        // 边框 + 圆角(Material 背景同步圆角防溢出)
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
                        return Material(
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
              // 窄屏(上下排):上方的图片顺序区同样加主题色 1px 边框 + 圆角
              SizedBox(
                height: 260,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: listPanel,
                ),
              ),
              const Divider(height: 1),
              Expanded(child: SafeArea(child: formPanel)),
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

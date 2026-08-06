import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/video_info.dart';
import '../../domain/value_objects/gif_setting.dart';
import '../../features/export/application/aspect_ratio.dart';
import '../../features/export/application/export_providers.dart';
import '../../features/export/application/export_state.dart';
import '../../features/export/presentation/export_complete_dialog.dart';
import '../../features/export/presentation/parameter_panel.dart';
import '../../features/preview/application/preview_providers.dart';
import '../../features/preview/presentation/preview_controls_bar.dart';
import '../../features/preview/presentation/video_preview_panel.dart';
import '../../features/timeline/application/timeline_providers.dart';
import '../../features/timeline/presentation/timeline_bar.dart';

/// 预览页组合壳(app 层组装,§5.3 app→features 仅组装)。
///
/// 跨模块 UI 组合收敛于此:预览(preview 模块)+ 导出区(export 模块)互不
/// 依赖;壳只做组装与生命周期转发(load / 导出终态弹窗),无业务逻辑。
/// 经路由 extra 接收 [VideoInfo];extra 为空(回退/深链)立即返回主页。
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.video, this.source});

  final VideoInfo? video;

  /// 采集来源(`capture`/`record`;路由 from query,普通导入为 null)。
  /// 决定 AppBar「重新拍摄/重新录屏」入口显示(来源专属,不混显)。
  final String? source;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  /// 右侧控制面板靠上对齐的高度阈值:右栏 maxHeight >= 此值视为
  /// 全屏/大窗口(面板加 Spacer 顶到顶部);否则保持原布局。
  static const double _outputPanelTopThreshold = 800;

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后加载,避免 initState 内触发 Notifier 状态写入
    Future.microtask(() {
      if (!mounted) return;
      final video = widget.video;
      if (video == null) {
        context.pop();
        return;
      }
      ref.read(previewControllerProvider.notifier).load(video);
      // 参数表单初始化(应用默认参数)
      ref.read(exportControllerProvider.notifier).initForm(video: video);
      // 时间轴初始化:选区取表单当前起止(initForm 之后)
      final form = ref.read(exportControllerProvider);
      ref
          .read(timelineControllerProvider.notifier)
          .init(
            videoDuration: video.duration,
            start: form.start,
            end: form.end,
          );
    });
    // 导出终态监听:完成 → 弹窗;失败/取消 → SnackBar(initState 用 listenManual)
    ref.listenManual<ExportFormState>(exportControllerProvider, (_, state) {
      if (!mounted) return;
      switch (state.lifecycle) {
        case ExportLifecycle.done:
          final task = state.task;
          if (task != null) {
            final notifier = ref.read(exportControllerProvider.notifier);
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
        case ExportLifecycle.failed:
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(state.errorMessage ?? '转换失败')),
            );
        case ExportLifecycle.idle:
        case ExportLifecycle.exporting:
          break;
      }
    }, fireImmediately: false);
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    if (video == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exporting =
        ref.watch(exportControllerProvider).lifecycle ==
        ExportLifecycle.exporting;
    // 全屏/大窗口判定:与 body 右栏同一阈值(窗口高 ≈ 右栏高 + AppBar 高,
    // 桌面端无系统栏裁剪;AppBar 贴顶不悬浮,两栏满铺无空隙)
    final largeWindow =
        MediaQuery.sizeOf(context).height >=
        _outputPanelTopThreshold + kToolbarHeight;
    return Scaffold(
      // 全屏/大窗口:顶部 AppBar(返回按钮区)同样加主题色 1px 边框 + 圆角,
      // 贴顶满铺不悬浮(无白色空隙);窄屏保持默认无边框
      appBar: AppBar(
        // Windows 反斜杠路径兼容(纯字符串处理,不触 IO)
        title: Text(video.path.split(RegExp(r'[\\/]')).last),
        leading: BackButton(onPressed: () => context.pop()),
        // 来源专属入口:拍摄来的仅「重新拍摄」,录屏来的仅「重新录屏」,
        // 普通导入(无 from)不显示;pushReplacement 直达不保留工作台栈
        actions: [
          if (widget.source == 'capture')
            IconButton(
              tooltip: '重新拍摄',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => context.pushReplacement('/capture'),
            ),
          if (widget.source == 'record')
            IconButton(
              tooltip: '重新录屏',
              icon: const Icon(Icons.screen_share_outlined),
              onPressed: () => context.pushReplacement('/record'),
            ),
        ],
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
      // 工作台双栏:中栏预览+控制条+时间轴;右栏参数面板(窄屏单列滚动)
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 预览画面按输出宽高比显示(宽高设置变化即时反映;单边/原图
          // = 源比例不变形,双边不匹配时显示拉伸效果与导出结果一致)
          final form = ref.watch(exportControllerProvider);
          final outputRatio = outputAspectRatio(
            GifSetting(width: form.width, height: form.height),
            video,
          );
          final previewArea = Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: outputRatio,
                child: VideoPreviewPanel(),
              ),
            ),
          );
          final previewColumn = Column(
            children: [
              previewArea,
              const SafeArea(child: PreviewControlsBar()),
              TimelineBar(enabled: !exporting),
            ],
          );
          final panel = _OutputControlPanel(
            child: ParameterPanel(video: video, enabled: !exporting),
          );
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                // 左栏预览区卡片:全屏/大窗口加主题色 1px 边框 + 圆角,
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
                            child: previewColumn,
                          );
                        }
                        return previewColumn;
                      },
                    ),
                  ),
                ),
                // 右栏参数面板卡片(同左栏;Material 背景同步圆角防溢出,
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
              previewArea,
              const SafeArea(child: PreviewControlsBar()),
              TimelineBar(enabled: !exporting),
              Flexible(child: SingleChildScrollView(child: panel)),
            ],
          );
        },
      ),
    );
  }
}

/// 输出控制面板封装:仅承载现有参数面板内容(保持不变,不做任何修改),
/// 布局排列(大窗口 Column+Spacer 靠上 / 小窗口仅面板)由壳在
/// LayoutBuilder 中按右栏高度决定。
class _OutputControlPanel extends StatelessWidget {
  const _OutputControlPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

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
  const PreviewScreen({super.key, required this.video});

  final VideoInfo? video;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
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
    return Scaffold(
      appBar: AppBar(
        // Windows 反斜杠路径兼容(纯字符串处理,不触 IO)
        title: Text(video.path.split(RegExp(r'[\\/]')).last),
        leading: BackButton(onPressed: () => context.pop()),
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
          final panel = ParameterPanel(video: video, enabled: !exporting);
          if (constraints.maxWidth >= 1024) {
            return Row(
              children: [
                Expanded(child: previewColumn),
                SizedBox(
                  width: 360,
                  child: SafeArea(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: panel,
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

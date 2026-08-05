import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/batch_session_controller.dart';
import '../router.dart';
import '../../features/task_queue/application/task_queue_providers.dart';
import '../../features/task_queue/application/task_queue_state.dart';
import 'batch_complete_dialog.dart';
import 'batch_failed_dialog.dart';
import 'import_actions.dart';

/// 批量完成弹窗宿主(全局常驻,挂在 MaterialApp.builder)。
///
/// 职责:监听批量会话声明 + 任务队列快照,经 [derive] 派生阶段;阶段
/// 变迁时经根 Navigator 弹出失败询问弹窗 / 最终完成弹窗;弹窗按钮动作
/// 统一收口(关闭 → 清理批次 → 导航)。
///
/// 导航机制:本组件 context 位于 MaterialApp.builder 层,在 Navigator
/// **之上**,不能直接 showDialog/context.go;统一经 [rootNavigatorKey]
/// (GoRouter.navigatorKey)取根 Navigator context(Navigator 在
/// GoRouter inherited 之下,context.go/push 可用)。
class BatchCompletionHost extends ConsumerStatefulWidget {
  const BatchCompletionHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BatchCompletionHost> createState() =>
      _BatchCompletionHostState();
}

class _BatchCompletionHostState extends ConsumerState<BatchCompletionHost> {
  /// 弹窗打开守卫:同一时刻只弹一个,防重复触发/嵌套竞态。
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    // 会话声明与队列快照任一变化都重新评估阶段(事件驱动闭环)
    ref.listenManual<BatchSessionState>(
      batchSessionProvider,
      (_, _) => _evaluate(),
    );
    ref.listenManual<TaskQueueState>(
      taskQueueControllerProvider,
      (_, _) => _evaluate(),
    );
    // 初始评估(挂载时批次可能已落定,如返回队列页场景)
    Future.microtask(_evaluate);
  }

  void _evaluate() {
    if (!mounted || _dialogOpen) return;
    final session = ref.read(batchSessionProvider);
    final queue = ref.read(taskQueueControllerProvider);
    final snapshot = derive(
      taskIds: session.taskIds,
      tasks: queue.tasks,
      declined: session.declined,
    );
    switch (snapshot.phase) {
      case BatchSessionPhase.none:
      case BatchSessionPhase.running:
        return;
      case BatchSessionPhase.askRetry:
        _showDialog(
          (dialogCtx) => BatchFailedDialog(
            items: snapshot.failedItems,
            onDecline: () => _dismiss(dialogCtx, () {
              ref.read(batchSessionProvider.notifier).decline();
              // 点"否"→ finished → 帧末再评估弹最终完成弹窗(旧弹窗先退场)
              WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
            }),
            onRetry: () => _dismiss(dialogCtx, () {
              ref.read(batchSessionProvider.notifier).retryFailed();
            }),
          ),
        );
      case BatchSessionPhase.finished:
        _showDialog(
          (dialogCtx) => BatchCompleteDialog(
            stats: snapshot.stats,
            // 打开文件夹不关闭弹窗(与单文件完成弹窗一致,可继续选去向)
            onOpenFolder: () {
              final paths = snapshot.stats.completedGifPaths;
              if (paths.isNotEmpty) {
                ref
                    .read(batchSessionProvider.notifier)
                    .openOutputFolder(
                      paths.first,
                      galleryUri: snapshot.stats.firstGalleryUri,
                    );
              }
            },
            onBackToBatch: () => _finish(dialogCtx, () {
              _navigate(
                (ctx) => ctx.go('/batch-import', extra: const <String>[]),
              );
            }),
            onSingleImport: () => _finish(dialogCtx, _singleImport),
            onBackHome: () => _finish(dialogCtx, () {
              _navigate((ctx) => ctx.go('/'));
            }),
          ),
        );
    }
  }

  /// 经根 Navigator 弹窗;根 Navigator 未挂载(测试注入无 key 的 router)
  /// 时静默跳过,避免宿主破坏无关测试。
  void _showDialog(Widget Function(BuildContext) builder) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    _dialogOpen = true;
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => builder(dialogCtx),
    );
  }

  /// 关闭弹窗 + 释放守卫 + 执行动作(失败弹窗按钮)。
  void _dismiss(BuildContext dialogCtx, VoidCallback action) {
    Navigator.of(dialogCtx).pop();
    _dialogOpen = false;
    action();
  }

  /// 关闭弹窗 + 清理批次(防重复弹)+ 导航(最终弹窗任一按钮)。
  void _finish(BuildContext dialogCtx, VoidCallback action) {
    Navigator.of(dialogCtx).pop();
    _dialogOpen = false;
    ref.read(batchSessionProvider.notifier).clear();
    action();
  }

  /// 经根 Navigator context 导航(context 常驻,go 重建栈后仍可用)。
  void _navigate(void Function(BuildContext ctx) action) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    action(ctx);
  }

  /// 返回单独导入mp4:回首页 + 自动打开文件选择器。
  Future<void> _singleImport() async {
    _navigate((ctx) => ctx.go('/'));
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    await pickMp4AndPreview(ctx, ref);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

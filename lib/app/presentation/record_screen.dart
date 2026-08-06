import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/features/screen_record/application/region_picker.dart';
import '../application/record_session_controller.dart';
import '../application/capture_entry_providers.dart';

/// 屏幕录制页(路由 /record;docs/19 S1-WP3)。
///
/// 启动即敏感内容确认横幅(19 号"录制范围确认提示放录制页启动时");
/// 状态机/计时/异常映射全部在 [RecordSessionController](application 层),
/// 本页只 watch 状态 + 转发事件;授权拒绝 → 控制器 errorMessage →
/// SnackBar 回 idle;返回取消兜底在控制器 onDispose。
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  @override
  void initState() {
    super.initState();
    // 选区归零与参数载入(2026-08-07 需求,控制器内写库)
    Future.microtask(() {
      if (!mounted) return;
      ref.read(recordSessionControllerProvider.notifier).init();
    });
    // 一次性错误文案 → SnackBar(消费后 clearError)
    ref.listenManual<RecordSessionState>(recordSessionControllerProvider, (
      _,
      state,
    ) {
      if (!mounted) return;
      final message = state.errorMessage;
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(recordSessionControllerProvider.notifier).clearError();
    }, fireImmediately: false);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(recordSessionControllerProvider);
    final notifier = ref.read(recordSessionControllerProvider.notifier);
    final phase = session.phase;
    final countdown = session.countdown;
    // 能力驱动渲染(区域 UI/授权文案/开始可用性);loading 按禁用防闪亮
    final caps = ref.watch(recordCapabilitiesProvider).value;
    final available = caps?.screenCaptureAvailable ?? false;
    final requiresConsent = caps?.requiresSystemConsent ?? false;
    final supportsRegions = caps?.supportsRegions ?? false;
    final hint = caps?.hint ?? '当前环境不支持屏幕录制';
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕录制')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 敏感内容确认横幅(录制范围确认,启动时展示;平台无关)
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '将录制屏幕内容(可能包含通知等敏感信息),仅用于生成 GIF,'
                        '请勿录制含敏感信息的内容',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 区域选择(桌面 x11grab/gdigrab;Android/Wayland 无此能力)
            if (supportsRegions) ...[
              const SizedBox(height: 16),
              const _RegionSelector(),
            ],
            const Spacer(),
            // 录制中:顶部倒计时 + 停止按钮;否则开始按钮
            if (phase == RecordPhase.recording) ...[
              Center(
                child: Text(
                  countdown,
                  style: TextStyle(
                    fontSize: 32,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: phase == RecordPhase.finishing
                      ? null
                      : notifier.stop,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  icon: const Icon(Icons.stop),
                  label: const Text('停止录制'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  requiresConsent ? '返回主屏后录制继续(状态栏通知可取消)' : '返回页面将取消本次录制',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else ...[
              Center(
                child: FilledButton.icon(
                  onPressed: phase == RecordPhase.idle && available
                      ? notifier.start
                      : null,
                  icon: const Icon(Icons.screen_share_outlined),
                  label: const Text('开始录制'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  available
                      ? (requiresConsent
                            ? '每次录制需系统授权;拒绝后可在本页重新发起'
                            : '录制完成后自动导入工作台回放确认')
                      : hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// 录制区域选择(全屏 / 自定义;桌面 x11grab/gdigrab 能力)。
///
/// settingsRepository 非响应式(Provider 不监听内部变化),点击切换后
/// 无重建驱动 —— 故本地持有选中态(StatefulWidget),变更同步 setState
/// + 持久化(record_params,与录制页启动读取同源)。
class _RegionSelector extends ConsumerStatefulWidget {
  const _RegionSelector();

  @override
  ConsumerState<_RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends ConsumerState<_RegionSelector> {
  late RecordParams _params;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    // 播种值 = 控制器载入并归零后的参数(选区归零写库在控制器 init,
    // 2026-08-07 需求;settingsRepository 非响应式,本地持有选中态)
    _params =
        ref.read(recordSessionControllerProvider).recordParams ??
        const RecordParams();
  }

  Future<void> _update(RecordParams next) async {
    setState(() => _params = next); // 立即重建(切换即时反馈)
    await ref
        .read(recordSessionControllerProvider.notifier)
        .updateRecordParams(next);
  }

  /// 鼠标框选录制范围(真实屏幕;slurp 交互选区;经控制器,回填同步)。
  Future<void> _pickRegion() async {
    setState(() => _picking = true);
    try {
      final next = await ref
          .read(recordSessionControllerProvider.notifier)
          .pickRegion();
      if (next != null && mounted) setState(() => _params = next);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    final custom = params.regionMode == RecordRegion.custom;
    final regionPickerAvailable = ref
        .read(screenRegionPickerProvider)
        .isAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('录制区域', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SegmentedButton<RecordRegion>(
              segments: const [
                ButtonSegment(
                  value: RecordRegion.fullscreen,
                  label: Text('全屏'),
                ),
                ButtonSegment(value: RecordRegion.custom, label: Text('自定义区域')),
              ],
              selected: {params.regionMode},
              onSelectionChanged: (s) =>
                  _update(params.copyWith(regionMode: s.first)),
            ),
            if (custom && regionPickerAvailable) ...[
              const SizedBox(height: 12),
              // 鼠标框选(Wayland slurp:全屏选区框,拖拽选取录制范围)
              FilledButton.tonalIcon(
                onPressed: _picking ? null : _pickRegion,
                icon: _picking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.crop_free),
                label: Text(_picking ? '在屏幕上拖拽选择区域…' : '框选录制范围'),
              ),
            ],
            if (custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      label: '起点 X',
                      value: params.regionX,
                      onChanged: (v) => _update(params.copyWith(regionX: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      label: '起点 Y',
                      value: params.regionY,
                      onChanged: (v) => _update(params.copyWith(regionY: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      label: '宽度',
                      value: params.regionWidth,
                      onChanged: (v) =>
                          _update(params.copyWith(regionWidth: v)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NumberField(
                      label: '高度',
                      value: params.regionHeight,
                      onChanged: (v) =>
                          _update(params.copyWith(regionHeight: v)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 数字输入框(非负整数;空/非法输入不更新,防误改)。
///
/// StatefulWidget 持有 [TextEditingController]:父级重建(如区域切换)
/// 不重建 controller,避免输入光标/焦点丢失。
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(_NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部值变化(拖拽回填/归零清空)同步到 controller;用户输入时
    // 值即时同步(无变化),不重置,保留光标位置。
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      controller: _controller,
      onChanged: (text) {
        final v = int.tryParse(text.trim());
        if (v == null || v < 0) return;
        widget.onChanged(v);
      },
    );
  }
}

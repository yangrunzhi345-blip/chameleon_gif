import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/features/screen_record/infrastructure/screen_recorder_port_impl.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import '../application/providers.dart';

/// 录制页状态机。
enum _RecordPhase { idle, awaitingConsent, recording, finishing }

/// 屏幕录制页(路由 /record;docs/19 S1-WP3)。
///
/// 启动即敏感内容确认横幅(19 号"录制范围确认提示放录制页启动时");
/// 开始 → [ScreenRecorderPort.record](系统授权对话框,Result 挂起至结束);
/// 停止/超时 → 自动导入 /preview;授权拒绝 → 提示回 idle;返回取消兜底
/// (cancelRecording,防前台服务泄漏)。
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  _RecordPhase _phase = _RecordPhase.idle;
  final _cancelToken = CancelToken();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    // 取消兜底(防前台服务泄漏;原生侧删 tmp)
    _cancelToken.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _phase = _RecordPhase.awaitingConsent);
    final port = ref.read(screenRecorderPortProvider);
    final params =
        ref.read(settingsRepositoryProvider).recordParams ??
        const RecordParams();
    try {
      // record 阻塞:系统授权 → 录制 → 手动停止/超时自动停 → 返回
      final result = await port.record(
        params: params,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      // 自动导入:素材 → ffprobe 解析 → /preview(预览返回回录制页)
      await ref.read(captureImportUseCaseProvider).execute(result.finalPath);
    } on CaptureCancelledException {
      // 静默:取消不提示
    } on CaptureException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } on FilePickException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } finally {
      _ticker?.cancel();
      if (mounted) {
        setState(() {
          _phase = _RecordPhase.idle;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  /// 停止按钮:经端口调原生 stopRecording(保存);record 的挂起 Result
  /// 由原生结束信号驱动返回。
  Future<void> _stop() async {
    setState(() => _phase = _RecordPhase.finishing);
    final port = ref.read(screenRecorderPortProvider);
    if (port is ScreenRecorderPortImpl) {
      await port.requestStop(); // 原生 stopRecording(保存)
    }
  }

  String get _countdown {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('屏幕录制')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 敏感内容确认横幅(录制范围确认,启动时展示)
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
                        '将录制整个屏幕(可能包含通知等敏感内容),仅用于生成 GIF,'
                        '请勿录制含敏感信息的内容',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // 录制中:顶部倒计时 + 停止按钮;否则开始按钮
            if (_phase == _RecordPhase.recording) ...[
              Center(
                child: Text(
                  _countdown,
                  style: TextStyle(
                    fontSize: 32,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: _phase == _RecordPhase.finishing ? null : _stop,
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
                  '返回主屏后录制继续(状态栏通知可取消)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else ...[
              Center(
                child: FilledButton.icon(
                  onPressed: _phase == _RecordPhase.idle ? _start : null,
                  icon: const Icon(Icons.screen_share_outlined),
                  label: const Text('开始录制'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '每次录制需系统授权;拒绝后可在本页重新发起',
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

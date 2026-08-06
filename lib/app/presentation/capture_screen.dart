import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_port_impl.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_preview_providers.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import '../application/providers.dart';

/// 拍摄页状态机(初始即 ready:取景异步加载不阻塞录制)。
enum _CapturePhase { ready, recording, finishing }

/// 相机拍摄页(路由 /capture;docs/18 C1-WP3)。
///
/// 壳只做渲染与转发:取景经 [cameraControllerProvider](null → 占位),
/// 编排(授权/录制)经 [cameraPortProvider];录制完成 → CaptureImportUseCase
/// 自动导入 /preview(预览返回回拍摄页,可连拍)。
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  // 初始即就绪:取景异步加载不阻塞录制(capture 内部会 ensureController)
  _CapturePhase _phase = _CapturePhase.ready;
  final _cancelToken = CancelToken();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    // 取消录制(不保存);相机会话释放由 cameraControllerProvider 的
    // autoDispose onDispose 收敛(dispose 内不可用 ref,见 provider 注释)
    _cancelToken.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _CapturePhase.recording;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(milliseconds: 500));
    });
    final port = ref.read(cameraPortProvider);
    // 记录设备方向(陀螺仪语义):方向修正据此判断横竖屏拍摄
    if (port is CameraPortImpl) {
      port.setDevicePortrait(
        MediaQuery.orientationOf(context) == Orientation.portrait,
      );
    }
    final params =
        ref.read(settingsRepositoryProvider).captureParams ??
        const CaptureParams();
    try {
      final result = await port.capture(
        params: params,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      // 自动导入:素材 → ffprobe 解析 → /preview(预览返回回拍摄页)
      await ref
          .read(captureImportUseCaseProvider)
          .execute(result.finalPath, source: CaptureSource.camera);
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
          _phase = _CapturePhase.ready;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _phase = _CapturePhase.finishing);
    final port = ref.read(cameraPortProvider);
    if (port is CameraPortImpl) {
      await port.stopCapture(); // 保存信号
    }
  }

  String get _countdown {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(cameraControllerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('相机拍摄'),
      ),
      body: Stack(
        children: [
          // 取景区:controller 就绪 → CameraPreview;否则占位三态。
          // 渲染 activeController ?? provider 值:会话重建(release→new)
          // 期间 activeController 为 null → 占位,永不渲染已 dispose
          // controller(真机实测 disposed CameraController 崩溃修复)
          Positioned.fill(
            child: preview.when(
              data: (controller) {
                final port = ref.read(cameraPortProvider);
                final active = port is CameraPortImpl
                    ? port.activeController
                    : null;
                final effective = active ?? controller;
                return effective == null
                    ? const _Placeholder(text: '未检测到摄像头,请检查相机权限')
                    // cover 填满:9:16 画面在 20:9 屏幕 letterbox 上下黑边
                    // 过宽(真机反馈),裁剪左右填满全屏(相机 app 惯例)
                    : SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 720,
                            height: 1280,
                            child: CameraPreview(effective),
                          ),
                        ),
                      );
              },
              loading: () => const _Placeholder(text: '相机启动中…'),
              error: (_, _) => _Placeholder(
                text: '相机启动失败',
                onRetry: () => ref.invalidate(cameraControllerProvider),
              ),
            ),
          ),
          // 顶部倒计时(仅录制中)
          if (_phase == _CapturePhase.recording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _countdown,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          // 底部录制按钮
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _phase == _CapturePhase.recording
                    ? _RecordButton(recording: true, onPressed: _stop)
                    : _RecordButton(
                        recording: false,
                        onPressed: _phase == _CapturePhase.ready
                            ? _start
                            : null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 占位文案(取景不可用时;error 态带重试)。
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white70)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

/// 录制按钮:就绪 = 大红圆;录制中 = 红底方钮(停止)。
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onPressed});

  final bool recording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (recording) {
      return FloatingActionButton(
        onPressed: enabled ? onPressed : null,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: '停止录制',
        child: const Icon(Icons.stop),
      );
    }
    return FloatingActionButton.large(
      onPressed: enabled ? onPressed : null,
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      tooltip: '开始录制',
      child: const Icon(Icons.circle_outlined),
    );
  }
}

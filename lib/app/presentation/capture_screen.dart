import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chameleon_gif/domain/exceptions/capture_exception.dart';
import 'package:chameleon_gif/domain/exceptions/file_pick_exception.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_source.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_port_impl.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_preview_providers.dart';
import 'package:chameleon_gif/features/camera/infrastructure/desktop_preview_providers.dart';
import 'package:chameleon_gif/features/camera/presentation/desktop_preview_view.dart';
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
    // 恢复自由旋转(录制锁定向兜底,防全局泄漏)
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  Future<void> _start() async {
    // 录制中锁定当前屏幕方向:旋转手机屏幕不跟随 → 录制键物理位置
    // 固定(用户要求"始终保持在竖屏位置",横屏不跑到横屏底部中央);
    // 锁 portraitUp/landscapeLeft,180° 翻转对底部中央按钮无影响。
    // 结束/dispose 恢复自由旋转。方向判定在 await 前完成(context 安全)。
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final devicePortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    await SystemChrome.setPreferredOrientations([
      isLandscape
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp,
    ]);
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
      port.setDevicePortrait(devicePortrait);
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
      // 恢复自由旋转(录制锁定向解除)
      await SystemChrome.setPreferredOrientations([]);
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
    await port.requestStop(); // 保存信号(接口统一:Android/桌面同语义)
  }

  String get _countdown {
    final s = _elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(cameraControllerProvider);
    // 桌面截帧预览流(Android null;预览会话生命周期经 provider 收敛)
    final desktopFrames = ref.watch(desktopPreviewFramesProvider).value;
    final recording = _phase == _CapturePhase.recording;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 黑色取景底:状态栏图标恒浅色(自绘顶栏,无 Scaffold.appBar 托管)
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
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
                  // 桌面截帧预览:帧流就绪 → JPEG 帧渲染;
                  // 预览不可用/无设备 → 盲拍兜底(录完回放确认,docs/18 D4)
                  if (port is! CameraPortImpl) {
                    final frames = desktopFrames;
                    if (frames != null) {
                      return DesktopPreviewView(frames: frames);
                    }
                    return const _BlindPlaceholder();
                  }
                  // Android:插件取景框(activeController 会话重建保护)
                  final active = port.activeController;
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
            // 顶部栏(标题 + 返回):录制中淡出,全屏拍摄;结束淡入恢复
            AnimatedOpacity(
              opacity: recording ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: recording,
                child: SafeArea(
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '返回',
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const Text(
                        '相机拍摄',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 顶部倒计时(仅录制中,淡入;与顶栏互斥显隐)
            AnimatedOpacity(
              opacity: recording ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !recording,
                child: SafeArea(
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
              ),
            ),
            // 底部录制按钮:固定位置不随横竖屏/SafeArea 变化
            // (真机反馈按钮位置漂移;固定偏移避开竖屏手势条)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: recording
                    ? _RecordButton(recording: true, onPressed: _stop)
                    : _RecordButton(
                        recording: false,
                        onPressed: _phase == _CapturePhase.ready
                            ? _start
                            : null,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预览不可用兜底占位(docs/18 D4):流预览启动失败/无设备时,录制
/// 完成后自动导入工作台回放确认;恒静态(无重试)。
class _BlindPlaceholder extends StatelessWidget {
  const _BlindPlaceholder();

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '相机预览不可用\n录制完成后自动导入工作台回放确认',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '相机参数可在应用设置中调整',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white54),
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

/// 录制按钮:开始/停止**固定 72×72 外框**,位置与大小完全一致
/// (真机反馈:大圆与方钮尺寸不同致切换时按键跳动)。
/// 开始 = 红圆 + 白圆环;停止 = 红圆 + 白圆角方块(视觉切换,轮廓不变)。
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onPressed});

  final bool recording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: recording ? '停止录制' : '开始录制',
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: enabled ? Colors.red : Colors.red.withValues(alpha: 0.4),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: recording
                  // 停止:白色圆角方块
                  ? Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                  // 开始:白色圆环
                  : Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

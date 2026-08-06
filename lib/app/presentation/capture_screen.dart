import 'package:camera/camera.dart' show CameraPreview;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chameleon_gif/features/camera/infrastructure/camera_port_impl.dart';
import 'package:chameleon_gif/features/camera/infrastructure/camera_preview_providers.dart';
import 'package:chameleon_gif/features/camera/infrastructure/desktop_preview_providers.dart';
import 'package:chameleon_gif/features/camera/presentation/desktop_preview_view.dart';
import 'package:chameleon_gif/shared/providers/core_providers.dart';
import '../application/capture_session_controller.dart';

/// 相机拍摄页(路由 /capture;docs/18 C1-WP3)。
///
/// 壳只做渲染与转发:取景经 [cameraControllerProvider](null → 占位),
/// 状态机/计时/异常映射在 [CaptureSessionController](application 层);
/// **SystemChrome 锁向/解锁留本页**(方向判定依赖 MediaQuery,且
/// flutter/services 禁入功能层),结束/dispose 恢复自由旋转。
/// 录制完成 → CaptureImportUseCase 自动导入 /preview(预览返回回拍摄页)。
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  @override
  void initState() {
    super.initState();
    // 一次性错误文案 → SnackBar(消费后 clearError)
    ref.listenManual<CaptureSessionState>(captureSessionControllerProvider, (
      _,
      state,
    ) {
      if (!mounted) return;
      final message = state.errorMessage;
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      ref.read(captureSessionControllerProvider.notifier).clearError();
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    // 恢复自由旋转(录制锁定向兜底,防全局泄漏);取消录制/计时在
    // 控制器 onDispose(autoDispose 随页面销毁收敛)
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  Future<void> _start() async {
    // 录制中锁定当前屏幕方向:旋转手机屏幕不跟随 → 录制键物理位置
    // 固定(用户要求"始终保持在竖屏位置",横屏不跑到横屏底部中央);
    // 锁 portraitUp/landscapeLeft,180° 翻转对底部中央按钮无影响。
    // 方向判定在 await 前完成(context 安全);锁向/解锁留 UI。
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final devicePortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    await SystemChrome.setPreferredOrientations([
      isLandscape
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp,
    ]);
    try {
      await ref
          .read(captureSessionControllerProvider.notifier)
          .start(portrait: devicePortrait);
    } finally {
      // 恢复自由旋转(录制锁定向解除;录制结束或异常均恢复)
      await SystemChrome.setPreferredOrientations([]);
    }
  }

  Future<void> _stop() async {
    await ref.read(captureSessionControllerProvider.notifier).stop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionControllerProvider);
    final phase = session.phase;
    final countdown = session.countdown;
    final preview = ref.watch(cameraControllerProvider);
    // 桌面截帧预览流(Android null;预览会话生命周期经 provider 收敛)
    final desktopFrames = ref.watch(desktopPreviewFramesProvider).value;
    final recording = phase == CapturePhase.recording;
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
                        countdown,
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
                        onPressed: phase == CapturePhase.ready ? _start : null,
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

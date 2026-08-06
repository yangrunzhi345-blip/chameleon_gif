import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/exceptions/capture_exception.dart';
import '../../domain/exceptions/file_pick_exception.dart';
import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../domain/value_objects/capture_params.dart';
import '../../domain/value_objects/capture_source.dart';
import '../../shared/providers/core_providers.dart';
import '../application/providers.dart';

/// 拍摄页会话状态机(初始即 ready:取景异步加载不阻塞录制)。
enum CapturePhase { ready, recording, finishing }

/// 拍摄会话状态(phase/计时/一次性错误文案)。
class CaptureSessionState {
  const CaptureSessionState({
    this.phase = CapturePhase.ready,
    this.elapsed = Duration.zero,
    this.errorMessage,
  });

  final CapturePhase phase;

  /// 已录制时长(500ms ticker 累加)。
  final Duration elapsed;

  /// 一次性错误文案(UI 消费后 clearError;取消静默不置)。
  final String? errorMessage;

  /// 倒计时文案(mm:ss)。
  String get countdown {
    final s = elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  CaptureSessionState copyWith({
    CapturePhase? phase,
    Duration? elapsed,
    Object? errorMessage = _unset,
  }) {
    return CaptureSessionState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const _unset = Object();
}

/// 相机拍摄会话控制器(app 层组合,autoDispose)。
///
/// 承载状态机(ready→recording→finishing)、500ms 计时、方向记录
/// (setDevicePortrait 接口方法,零类型分支)、拍摄参数载入、自动导入
/// 与异常映射(取消静默、其余 → errorMessage 一次性消费)。
/// **SystemChrome 锁向/解锁留 UI**(方向判定依赖 MediaQuery,且
/// flutter/services 禁入功能层),控制器只暴露 [start(portrait:)]。
/// dispose(onDispose)取消令牌与计时器;相机会话释放由
/// cameraControllerProvider 的 autoDispose onDispose 收敛。
class CaptureSessionController extends Notifier<CaptureSessionState> {
  final _cancelToken = CancelToken();
  Timer? _ticker;

  @override
  CaptureSessionState build() {
    ref.onDispose(() {
      // 取消录制(不保存);相机会话释放由 provider 收敛
      _cancelToken.cancel();
      _ticker?.cancel();
    });
    return const CaptureSessionState();
  }

  /// 开始拍摄:录制态 + 计时 + 方向记录 + 拍摄(阻塞)→ 自动导入 /preview。
  ///
  /// [portrait] 为拍摄时设备方向(拍摄页 MediaQuery 提供,陀螺仪语义;
  /// 方向修正 [CameraPort.setDevicePortrait] 据此判断横竖屏拍摄)。
  Future<void> start({required bool portrait}) async {
    state = state.copyWith(
      phase: CapturePhase.recording,
      elapsed: Duration.zero,
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(milliseconds: 500),
      );
    });
    final port = ref.read(cameraPortProvider);
    await port.setDevicePortrait(portrait);
    final params =
        ref.read(settingsRepositoryProvider).captureParams ??
        const CaptureParams();
    try {
      final result = await port.capture(
        params: params,
        cancelToken: _cancelToken,
      );
      if (!ref.mounted) return;
      // 自动导入:素材 → ffprobe 解析 → /preview(预览返回回拍摄页)
      await ref
          .read(captureImportUseCaseProvider)
          .execute(result.finalPath, source: CaptureSource.camera);
    } on CaptureCancelledException {
      // 静默:取消不提示
    } on CaptureException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.userMessage);
    } on FilePickException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.userMessage);
    } finally {
      _ticker?.cancel();
      if (ref.mounted) {
        state = state.copyWith(
          phase: CapturePhase.ready,
          elapsed: Duration.zero,
        );
      }
    }
  }

  /// 停止按钮:经端口 requestStop(保存信号;接口统一 Android/桌面同语义)。
  Future<void> stop() async {
    state = state.copyWith(phase: CapturePhase.finishing);
    await ref.read(cameraPortProvider).requestStop();
  }

  /// 一次性错误消费(UI 展示 SnackBar 后调用)。
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

/// 拍摄会话 provider(autoDispose 随页面销毁)。
final captureSessionControllerProvider =
    NotifierProvider.autoDispose<CaptureSessionController, CaptureSessionState>(
      CaptureSessionController.new,
    );

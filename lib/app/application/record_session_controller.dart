import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/exceptions/capture_exception.dart';
import '../../domain/exceptions/file_pick_exception.dart';
import '../../domain/repository_interfaces/ffmpeg_engine.dart';
import '../../domain/value_objects/capture_source.dart';
import '../../domain/value_objects/record_params.dart';
import '../../features/screen_record/application/region_picker.dart';
import '../../shared/providers/core_providers.dart';
import '../application/providers.dart';

/// 录制页会话状态机。
enum RecordPhase { idle, awaitingConsent, recording, finishing }

/// 录制会话状态(phase/计时/一次性错误文案/录制参数)。
class RecordSessionState {
  const RecordSessionState({
    this.phase = RecordPhase.idle,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.recordParams,
  });

  final RecordPhase phase;

  /// 已录制时长(500ms ticker 累加)。
  final Duration elapsed;

  /// 一次性错误文案(UI 消费后 clearError;取消静默不置)。
  final String? errorMessage;

  /// 录制参数(选区归零后值;供区域选择器播种)。
  final RecordParams? recordParams;

  /// 倒计时文案(mm:ss)。
  String get countdown {
    final s = elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  RecordSessionState copyWith({
    RecordPhase? phase,
    Duration? elapsed,
    Object? errorMessage = _unset,
    Object? recordParams = _unset,
  }) {
    return RecordSessionState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      recordParams: identical(recordParams, _unset)
          ? this.recordParams
          : recordParams as RecordParams?,
    );
  }

  static const _unset = Object();
}

/// 屏幕录制会话控制器(app 层组合,autoDispose)。
///
/// 承载状态机(idle→awaitingConsent→recording→finishing)、500ms 计时、
/// 录制参数载入与选区归零写库(2026-08-07 需求)、框选/参数持久化、
/// 自动导入与异常映射(取消静默、其余 → errorMessage 一次性消费)。
/// dispose(onDispose)取消令牌与计时器,防前台服务泄漏。
class RecordSessionController extends Notifier<RecordSessionState> {
  final _cancelToken = CancelToken();
  Timer? _ticker;

  @override
  RecordSessionState build() {
    ref.onDispose(() {
      // 取消兜底(防前台服务泄漏;原生侧删 tmp)+ 停计时
      _cancelToken.cancel();
      _ticker?.cancel();
    });
    return const RecordSessionState();
  }

  /// 会话初始化:载入录制参数并**归零选区**(每次重新进入录制页选区
  /// 默认归零,持久化同步,保证「开始录制」读到归零值,不残留旧区域)。
  void init() {
    final repo = ref.read(settingsRepositoryProvider);
    final current = repo.recordParams ?? const RecordParams();
    if (current.regionX != null ||
        current.regionY != null ||
        current.regionWidth != null ||
        current.regionHeight != null) {
      // 仅区域字段清空(freezed copyWith 传 null 不修改,故重构造)
      final zeroed = RecordParams(
        fps: current.fps,
        maxDurationMs: current.maxDurationMs,
        regionMode: current.regionMode,
        windowTitle: current.windowTitle,
        drawCursor: current.drawCursor,
        aspectRatio: current.aspectRatio,
        outputDir: current.outputDir,
      );
      unawaited(repo.setRecordParams(zeroed));
      state = state.copyWith(recordParams: zeroed);
    } else {
      state = state.copyWith(recordParams: current);
    }
  }

  /// 参数更新(区域切换/数字输入/框选回填):写库 + 状态同步。
  Future<void> updateRecordParams(RecordParams next) async {
    state = state.copyWith(recordParams: next);
    await ref.read(settingsRepositoryProvider).setRecordParams(next);
  }

  /// 鼠标框选录制范围(真实屏幕;slurp 交互选区;取消/失败返回 null)。
  ///
  /// 返回更新后的参数(UI 本地选中态随之同步 —— settingsRepository 非
  /// 响应式,回填 geometry 是页面局部交互)。
  Future<RecordParams?> pickRegion() async {
    final region = await ref.read(screenRegionPickerProvider).pick();
    if (region == null || !ref.mounted) return null;
    final params = state.recordParams ?? const RecordParams();
    final next = params.copyWith(
      regionX: region.x,
      regionY: region.y,
      regionWidth: region.width,
      regionHeight: region.height,
    );
    await updateRecordParams(next);
    return next;
  }

  /// 开始录制:敏感确认 → 系统授权 → 录制(阻塞)→ 自动导入 /preview。
  Future<void> start() async {
    state = state.copyWith(phase: RecordPhase.awaitingConsent);
    final port = ref.read(screenRecorderPortProvider);
    final params =
        ref.read(settingsRepositoryProvider).recordParams ??
        const RecordParams();
    try {
      // 录制中态:record 阻塞期间显示停止按钮(awaitingConsent 仅瞬态 ——
      // record 内部授权+录制无"开始"回调,统一按录制中渲染;
      // 授权拒绝/失败由 record 抛异常回 idle)
      state = state.copyWith(phase: RecordPhase.recording);
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!ref.mounted) return;
        state = state.copyWith(
          elapsed: state.elapsed + const Duration(milliseconds: 500),
        );
      });
      // record 阻塞:系统授权 → 录制 → 手动停止/超时自动停 → 返回
      final result = await port.record(
        params: params,
        cancelToken: _cancelToken,
      );
      if (!ref.mounted) return;
      // 自动导入:素材 → ffprobe 解析 → /preview(预览返回回录制页)
      await ref
          .read(captureImportUseCaseProvider)
          .execute(result.finalPath, source: CaptureSource.screenRecord);
    } on CaptureCancelledException {
      // 静默:取消不提示
    } on CaptureException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.userMessage);
    } on FilePickException catch (e) {
      if (ref.mounted) state = state.copyWith(errorMessage: e.userMessage);
    } finally {
      _ticker?.cancel();
      if (ref.mounted) {
        state = state.copyWith(phase: RecordPhase.idle, elapsed: Duration.zero);
      }
    }
  }

  /// 停止按钮:经端口 requestStop(保存);record 的挂起 Result 由
  /// 结束信号驱动返回(接口统一:Android 原生通道 / 桌面 SIGTERM)。
  Future<void> stop() async {
    state = state.copyWith(phase: RecordPhase.finishing);
    await ref.read(screenRecorderPortProvider).requestStop();
  }

  /// 一次性错误消费(UI 展示 SnackBar 后调用)。
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}

/// 录制会话 provider(autoDispose 随页面销毁)。
final recordSessionControllerProvider =
    NotifierProvider.autoDispose<RecordSessionController, RecordSessionState>(
      RecordSessionController.new,
    );

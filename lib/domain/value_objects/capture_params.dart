import 'package:freezed_annotation/freezed_annotation.dart';

part 'capture_params.freezed.dart';
part 'capture_params.g.dart';

/// 对焦模式(Android camera 插件语义;桌面端按设备能力裁剪)。
enum FocusMode { auto, continuous, manual }

/// 相机拍摄参数(docs/18 §5.1)。
///
/// 平台语义:Android 不设分辨率(相机硬件最优,D3 决策),桌面端
/// [resolutionWidth]/[resolutionHeight] 生效;新增字段一律带默认值,
/// 老 JSON 兼容(设置页持久化 key 见阶段 C)。
@freezed
abstract class CaptureParams with _$CaptureParams {
  const CaptureParams._();

  const factory CaptureParams({
    /// 目标设备标识(null = 默认后置摄像头;Android 前后摄,桌面 /dev/videoN)
    String? deviceId,

    /// 帧率(1–60)
    @Default(15.0) double fps,

    /// 桌面端:采集分辨率宽度;Android 忽略
    int? resolutionWidth,

    /// 桌面端:采集分辨率高度;Android 忽略
    int? resolutionHeight,

    /// 时长上限(毫秒,超时自动停)
    @Default(30000) int maxDurationMs,

    /// 白平衡色温(K)
    int? whiteBalanceTemp,

    /// 白平衡自动(默认开,与相机自动白平衡默认态一致)
    @Default(true) bool whiteBalanceAuto,

    /// 曝光补偿
    double? exposureCompensation,

    /// 曝光锁定
    @Default(false) bool exposureLock,

    /// ISO 感光度
    int? iso,

    /// 对焦模式
    @Default(FocusMode.auto) FocusMode focusMode,

    /// 变焦倍数
    double? zoom,

    /// 闪光灯
    @Default(false) bool flashOn,

    /// 桌面端:素材目录;null = 默认 capturesDir
    String? outputDir,
  }) = _CaptureParams;

  factory CaptureParams.fromJson(Map<String, dynamic> json) =>
      _$CaptureParamsFromJson(json);
}

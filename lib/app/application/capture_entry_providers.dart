import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/record_types.dart';
import '../../shared/providers/core_providers.dart';

/// 首页采集入口可用性(能力驱动;docs/18 §五"置灰不隐藏")。
///
/// autoDispose:离开首页再进入时重新探测 —— 环境动态(插上摄像头即恢复,
/// 切会话后录屏可用性刷新),探测为轻量子进程(毫秒级)。
///
/// 使用约定:UI 在 provider 未完成(loading,value == null)时按**禁用**
/// 渲染(防闪亮,避免入口瞬间可用又置灰的闪烁)。

/// 相机入口:enumerateDevices 非空即可用(Android 恒前后摄;Linux 扫
/// /dev/video*;Windows dshow 枚举)。
final cameraEntryAvailableProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final devices = await ref.watch(cameraPortProvider).enumerateDevices();
  return devices.isNotEmpty;
});

/// 录屏入口:queryCapabilities 探测结果(screenCaptureAvailable 决定
/// 置灰与否;hint 作 tooltip 指引)。
final recordEntryAvailableProvider =
    FutureProvider.autoDispose<RecordCapabilities>(
      (ref) => ref.watch(screenRecorderPortProvider).queryCapabilities(),
    );

/// 录制页能力(区域 UI 显隐 / 授权文案 / 开始按钮可用性渲染依据)。
///
/// 非 autoDispose:录制页内跨重建稳定(与入口探测分离,各自失效策略)。
final recordCapabilitiesProvider = FutureProvider<RecordCapabilities>(
  (ref) => ref.watch(screenRecorderPortProvider).queryCapabilities(),
);

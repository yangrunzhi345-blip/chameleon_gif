import 'package:chameleon_gif/domain/repository_interfaces/camera_port.dart';
import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/value_objects/camera_types.dart';
import 'package:chameleon_gif/domain/value_objects/capture_params.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';

/// [CameraPort] 测试替身(阶段 A-WP3;仿 fake_ffmpeg_service 手写风格)。
///
/// 可配:设备列表/能力/常错/行为回调([onCapture]);记录全部调用
/// ([captureCalls]/[applyParamsCalls]/[queryCapabilitiesCalls] 等),
/// 供断言"传入参数"与"调用次数"。
class FakeCameraPort implements CameraPort {
  FakeCameraPort({
    this.devices = const [CameraDevice(id: 'front', name: '前置摄像头')],
    this.capabilities = const CameraCapabilities(),
    this.onCapture,
    this.error,
    this.previewSupported = true,
  });

  /// 枚举返回的设备列表。
  final List<CameraDevice> devices;

  /// 能力探测返回值。
  final CameraCapabilities capabilities;

  /// 行为回调:注入"夹具拷贝 + 真实命名"等场景;缺省返回空结果。
  /// 非 final:测试在容器装配后动态注入(闭包引用测试适配器)。
  Future<CaptureResult> Function(
    CaptureParams params,
    CancelToken? cancelToken,
  )?
  onCapture;

  /// 常错注入(模拟授权拒绝等);非空时 capture 直接抛。
  Object? error;

  /// 取景能力(盲拍测试置 false;可变 —— 容器持有对象引用,
  /// 测试中途改字段无需重建容器)。
  @override
  bool previewSupported;

  final captureCalls = <CaptureParams>[];
  final requestStopCalls = <int>[];
  final applyParamsCalls = <CaptureParams>[];
  final enumerateDevicesCalls = <int>[];
  final queryCapabilitiesCalls = <String>[];
  CancelToken? lastCancelToken;

  @override
  Future<CaptureResult> capture({
    required CaptureParams params,
    CancelToken? cancelToken,
  }) async {
    captureCalls.add(params);
    lastCancelToken = cancelToken;
    final e = error;
    if (e != null) throw e;
    final handler = onCapture;
    if (handler != null) return handler(params, cancelToken);
    return const CaptureResult(finalPath: '', durationMs: 0);
  }

  @override
  Future<void> applyParams(CaptureParams params) async {
    applyParamsCalls.add(params);
  }

  @override
  Future<List<CameraDevice>> enumerateDevices() async {
    enumerateDevicesCalls.add(1);
    return devices;
  }

  @override
  Future<CameraCapabilities> queryCapabilities(String deviceId) async {
    queryCapabilitiesCalls.add(deviceId);
    return capabilities;
  }

  @override
  Future<void> requestStop() async {
    requestStopCalls.add(1);
  }
}

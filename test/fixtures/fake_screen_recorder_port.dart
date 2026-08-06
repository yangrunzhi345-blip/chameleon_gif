import 'package:chameleon_gif/domain/repository_interfaces/ffmpeg_engine.dart';
import 'package:chameleon_gif/domain/repository_interfaces/screen_recorder_port.dart';
import 'package:chameleon_gif/domain/value_objects/capture_result.dart';
import 'package:chameleon_gif/domain/value_objects/record_params.dart';
import 'package:chameleon_gif/domain/value_objects/record_types.dart';

/// [ScreenRecorderPort] 测试替身(阶段 A-WP3;与 FakeCameraPort 同构)。
///
/// 可配:目标列表/能力/常错/行为回调([onRecord]);记录全部调用
/// ([recordCalls]/[enumerateTargetsCalls] 等)。
class FakeScreenRecorderPort implements ScreenRecorderPort {
  FakeScreenRecorderPort({
    this.targets = const [RecordTarget(id: '0', title: '全屏')],
    this.capabilities = const RecordCapabilities(),
    this.onRecord,
    this.error,
  });

  /// 枚举返回的目标列表。
  final List<RecordTarget> targets;

  /// 环境能力返回值(可变:测试中途改字段无需重建容器)。
  RecordCapabilities capabilities;

  /// 行为回调:注入"夹具拷贝 + 真实命名"等场景;缺省返回空结果。
  /// 非 final:测试在容器装配后动态注入(闭包引用测试适配器)。
  Future<CaptureResult> Function(RecordParams params, CancelToken? cancelToken)?
  onRecord;

  /// 常错注入;非空时 record 直接抛。
  Object? error;

  final recordCalls = <RecordParams>[];
  final enumerateTargetsCalls = <int>[];
  final queryCapabilitiesCalls = <int>[];
  final requestStopCalls = <int>[];
  CancelToken? lastCancelToken;

  @override
  Future<CaptureResult> record({
    required RecordParams params,
    CancelToken? cancelToken,
  }) async {
    recordCalls.add(params);
    lastCancelToken = cancelToken;
    final e = error;
    if (e != null) throw e;
    final handler = onRecord;
    if (handler != null) return handler(params, cancelToken);
    return const CaptureResult(finalPath: '', durationMs: 0);
  }

  @override
  Future<List<RecordTarget>> enumerateTargets() async {
    enumerateTargetsCalls.add(1);
    return targets;
  }

  @override
  Future<RecordCapabilities> queryCapabilities() async {
    queryCapabilitiesCalls.add(1);
    return capabilities;
  }

  @override
  Future<void> requestStop() async {
    requestStopCalls.add(1);
  }
}

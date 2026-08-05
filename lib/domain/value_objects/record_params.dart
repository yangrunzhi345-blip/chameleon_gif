import 'package:freezed_annotation/freezed_annotation.dart';

part 'record_params.freezed.dart';
part 'record_params.g.dart';

/// 录制区域模式(全屏/窗口/自定义)。
enum RecordRegion { fullscreen, window, custom }

/// 录屏参数(docs/19 §3.1)。
///
/// 与文档草案的偏差:区域字段用四个 int 原语
/// ([regionX]/[regionY]/[regionWidth]/[regionHeight])而非 Offset/Size,
/// 保证 domain 层零 Flutter 依赖(CLAUDE.md §5.6 红线)且 JSON 友好;
/// 新增字段一律带默认值,老 JSON 兼容。
@freezed
abstract class RecordParams with _$RecordParams {
  const RecordParams._();

  const factory RecordParams({
    /// 帧率(5–30)
    @Default(15.0) double fps,

    /// 时长上限(毫秒,超时自动停)
    @Default(60000) int maxDurationMs,

    /// 区域模式(Windows gdigrab;Android 恒全屏)
    @Default(RecordRegion.fullscreen) RecordRegion regionMode,

    /// 窗口模式:目标窗口标题(gdigrab `title=`)
    String? windowTitle,

    /// 自定义区域起点 X(gdigrab offset / x11grab `DISPLAY+x+y`)
    int? regionX,

    /// 自定义区域起点 Y
    int? regionY,

    /// 自定义区域宽度
    int? regionWidth,

    /// 自定义区域高度
    int? regionHeight,

    /// 是否显示光标(gdigrab 默认带;x11grab 需 `-draw_mouse`)
    @Default(true) bool drawCursor,

    /// Android:虚拟显示比例(如 16/9);null = 全屏原生比例
    double? aspectRatio,

    /// 桌面端:素材目录;null = 默认 capturesDir
    String? outputDir,
  }) = _RecordParams;

  factory RecordParams.fromJson(Map<String, dynamic> json) =>
      _$RecordParamsFromJson(json);
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecordParams _$RecordParamsFromJson(Map<String, dynamic> json) =>
    _RecordParams(
      fps: (json['fps'] as num?)?.toDouble() ?? 15.0,
      maxDurationMs: (json['maxDurationMs'] as num?)?.toInt() ?? 0,
      regionMode:
          $enumDecodeNullable(_$RecordRegionEnumMap, json['regionMode']) ??
          RecordRegion.fullscreen,
      windowTitle: json['windowTitle'] as String?,
      regionX: (json['regionX'] as num?)?.toInt(),
      regionY: (json['regionY'] as num?)?.toInt(),
      regionWidth: (json['regionWidth'] as num?)?.toInt(),
      regionHeight: (json['regionHeight'] as num?)?.toInt(),
      drawCursor: json['drawCursor'] as bool? ?? true,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
      outputDir: json['outputDir'] as String?,
    );

Map<String, dynamic> _$RecordParamsToJson(_RecordParams instance) =>
    <String, dynamic>{
      'fps': instance.fps,
      'maxDurationMs': instance.maxDurationMs,
      'regionMode': _$RecordRegionEnumMap[instance.regionMode]!,
      'windowTitle': instance.windowTitle,
      'regionX': instance.regionX,
      'regionY': instance.regionY,
      'regionWidth': instance.regionWidth,
      'regionHeight': instance.regionHeight,
      'drawCursor': instance.drawCursor,
      'aspectRatio': instance.aspectRatio,
      'outputDir': instance.outputDir,
    };

const _$RecordRegionEnumMap = {
  RecordRegion.fullscreen: 'fullscreen',
  RecordRegion.window: 'window',
  RecordRegion.custom: 'custom',
};

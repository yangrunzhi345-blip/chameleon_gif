// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CaptureParams _$CaptureParamsFromJson(Map<String, dynamic> json) =>
    _CaptureParams(
      deviceId: json['deviceId'] as String?,
      fps: (json['fps'] as num?)?.toDouble() ?? 15.0,
      resolutionWidth: (json['resolutionWidth'] as num?)?.toInt(),
      resolutionHeight: (json['resolutionHeight'] as num?)?.toInt(),
      maxDurationMs: (json['maxDurationMs'] as num?)?.toInt() ?? 30000,
      whiteBalanceTemp: (json['whiteBalanceTemp'] as num?)?.toInt(),
      whiteBalanceAuto: json['whiteBalanceAuto'] as bool? ?? true,
      exposureCompensation: (json['exposureCompensation'] as num?)?.toDouble(),
      exposureLock: json['exposureLock'] as bool? ?? false,
      iso: (json['iso'] as num?)?.toInt(),
      focusMode:
          $enumDecodeNullable(_$FocusModeEnumMap, json['focusMode']) ??
          FocusMode.auto,
      zoom: (json['zoom'] as num?)?.toDouble(),
      flashOn: json['flashOn'] as bool? ?? false,
      outputDir: json['outputDir'] as String?,
      v4l2Controls:
          (json['v4l2Controls'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
    );

Map<String, dynamic> _$CaptureParamsToJson(_CaptureParams instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'fps': instance.fps,
      'resolutionWidth': instance.resolutionWidth,
      'resolutionHeight': instance.resolutionHeight,
      'maxDurationMs': instance.maxDurationMs,
      'whiteBalanceTemp': instance.whiteBalanceTemp,
      'whiteBalanceAuto': instance.whiteBalanceAuto,
      'exposureCompensation': instance.exposureCompensation,
      'exposureLock': instance.exposureLock,
      'iso': instance.iso,
      'focusMode': _$FocusModeEnumMap[instance.focusMode]!,
      'zoom': instance.zoom,
      'flashOn': instance.flashOn,
      'outputDir': instance.outputDir,
      'v4l2Controls': instance.v4l2Controls,
    };

const _$FocusModeEnumMap = {
  FocusMode.auto: 'auto',
  FocusMode.continuous: 'continuous',
  FocusMode.manual: 'manual',
};

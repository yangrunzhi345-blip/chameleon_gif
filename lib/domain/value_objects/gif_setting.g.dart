// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gif_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GifSetting _$GifSettingFromJson(Map<String, dynamic> json) => _GifSetting(
  fps: (json['fps'] as num?)?.toDouble() ?? 15.0,
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
  start: json['start'] == null
      ? Duration.zero
      : Duration(microseconds: (json['start'] as num).toInt()),
  end: json['end'] == null
      ? null
      : Duration(microseconds: (json['end'] as num).toInt()),
  loop: (json['loop'] as num?)?.toInt() ?? 0,
  frameDurationMs: (json['frameDurationMs'] as num?)?.toInt(),
  usePalette: json['usePalette'] as bool? ?? true,
  scaleMultiplier: (json['scaleMultiplier'] as num?)?.toDouble() ?? 1.0,
  playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$GifSettingToJson(_GifSetting instance) =>
    <String, dynamic>{
      'fps': instance.fps,
      'width': instance.width,
      'height': instance.height,
      'start': instance.start.inMicroseconds,
      'end': instance.end?.inMicroseconds,
      'loop': instance.loop,
      'frameDurationMs': instance.frameDurationMs,
      'usePalette': instance.usePalette,
      'scaleMultiplier': instance.scaleMultiplier,
      'playbackSpeed': instance.playbackSpeed,
    };

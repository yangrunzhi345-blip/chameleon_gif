// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VideoInfo _$VideoInfoFromJson(Map<String, dynamic> json) => _VideoInfo(
  path: json['path'] as String,
  formatName: json['formatName'] as String,
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  fps: (json['fps'] as num?)?.toDouble(),
  codec: json['codec'] as String,
);

Map<String, dynamic> _$VideoInfoToJson(_VideoInfo instance) =>
    <String, dynamic>{
      'path': instance.path,
      'formatName': instance.formatName,
      'duration': instance.duration.inMicroseconds,
      'width': instance.width,
      'height': instance.height,
      'fps': instance.fps,
      'codec': instance.codec,
    };

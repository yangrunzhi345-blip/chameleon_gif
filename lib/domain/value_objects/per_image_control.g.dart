// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'per_image_control.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PerImageControl _$PerImageControlFromJson(Map<String, dynamic> json) =>
    _PerImageControl(
      scaleMultiplier: (json['scaleMultiplier'] as num?)?.toDouble() ?? 1.0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PerImageControlToJson(_PerImageControl instance) =>
    <String, dynamic>{
      'scaleMultiplier': instance.scaleMultiplier,
      'width': instance.width,
      'height': instance.height,
    };

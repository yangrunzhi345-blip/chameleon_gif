// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskProgress _$TaskProgressFromJson(Map<String, dynamic> json) =>
    _TaskProgress(
      taskId: (json['taskId'] as num).toInt(),
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      elapsed: json['elapsed'] == null
          ? Duration.zero
          : Duration(microseconds: (json['elapsed'] as num).toInt()),
      remaining: json['remaining'] == null
          ? null
          : Duration(microseconds: (json['remaining'] as num).toInt()),
      speedKbPerSec: (json['speedKbPerSec'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TaskProgressToJson(_TaskProgress instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'percent': instance.percent,
      'elapsed': instance.elapsed.inMicroseconds,
      'remaining': instance.remaining?.inMicroseconds,
      'speedKbPerSec': instance.speedKbPerSec,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gif_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GifSetting {

/// 输出帧率(1–60)
 double get fps;/// 输出宽度(0 = 原图等比,默认)
 int get width;/// 输出高度(0 = 原图等比,默认;与宽度同时指定时按指定尺寸输出)
 int get height;/// 输出起点(相对源视频)
 Duration get start;/// 输出终点(默认取源视频时长,由导入时填充)
 Duration? get end;/// 循环次数(0 = 无限循环)
 int get loop;/// 图片模式:每张图片停留时长(毫秒);null = 由 [fps] 推导(每图一帧)。
/// 视频模式不读取该字段。
 int? get frameDurationMs;/// 图片模式:质量开关;true = 调色板两遍(高质,默认),false = 标准单遍。
/// 视频模式不读取该字段(视频 UI 无质量开关,恒走两遍)。
 bool get usePalette;/// 输出等比缩放倍数(0.5/0.75/1/1.5/2/3;1.0 = 不缩放,默认)。
///
/// 源尺寸已知时选倍数会联动落成具体 width/height;本字段是
/// "偏好/展开语义":批量入队时若 width==height==0 且 m!=1.0,
/// 按各视频自身尺寸 × m 展开(见 scale_multiplier.dart)。
 double get scaleMultiplier;/// 播放速度(0.25–4:0.25/0.5 慢放,1.0 正常,≥2 加速;默认 1.0)。
///
/// 命令侧经滤镜链 `setpts=PTS/<speed>` 实现:帧数不变、输出时间轴
/// 等比缩放(加速 → 总时长缩短,慢放 → 拉长);视频模式裁剪
/// `-ss`/`-to` 作用于源时间轴,不受速度影响;1.0 不注入滤镜(快照不变)。
 double get playbackSpeed;
/// Create a copy of GifSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GifSettingCopyWith<GifSetting> get copyWith => _$GifSettingCopyWithImpl<GifSetting>(this as GifSetting, _$identity);

  /// Serializes this GifSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GifSetting&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.loop, loop) || other.loop == loop)&&(identical(other.frameDurationMs, frameDurationMs) || other.frameDurationMs == frameDurationMs)&&(identical(other.usePalette, usePalette) || other.usePalette == usePalette)&&(identical(other.scaleMultiplier, scaleMultiplier) || other.scaleMultiplier == scaleMultiplier)&&(identical(other.playbackSpeed, playbackSpeed) || other.playbackSpeed == playbackSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,width,height,start,end,loop,frameDurationMs,usePalette,scaleMultiplier,playbackSpeed);

@override
String toString() {
  return 'GifSetting(fps: $fps, width: $width, height: $height, start: $start, end: $end, loop: $loop, frameDurationMs: $frameDurationMs, usePalette: $usePalette, scaleMultiplier: $scaleMultiplier, playbackSpeed: $playbackSpeed)';
}


}

/// @nodoc
abstract mixin class $GifSettingCopyWith<$Res>  {
  factory $GifSettingCopyWith(GifSetting value, $Res Function(GifSetting) _then) = _$GifSettingCopyWithImpl;
@useResult
$Res call({
 double fps, int width, int height, Duration start, Duration? end, int loop, int? frameDurationMs, bool usePalette, double scaleMultiplier, double playbackSpeed
});




}
/// @nodoc
class _$GifSettingCopyWithImpl<$Res>
    implements $GifSettingCopyWith<$Res> {
  _$GifSettingCopyWithImpl(this._self, this._then);

  final GifSetting _self;
  final $Res Function(GifSetting) _then;

/// Create a copy of GifSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fps = null,Object? width = null,Object? height = null,Object? start = null,Object? end = freezed,Object? loop = null,Object? frameDurationMs = freezed,Object? usePalette = null,Object? scaleMultiplier = null,Object? playbackSpeed = null,}) {
  return _then(_self.copyWith(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as int,frameDurationMs: freezed == frameDurationMs ? _self.frameDurationMs : frameDurationMs // ignore: cast_nullable_to_non_nullable
as int?,usePalette: null == usePalette ? _self.usePalette : usePalette // ignore: cast_nullable_to_non_nullable
as bool,scaleMultiplier: null == scaleMultiplier ? _self.scaleMultiplier : scaleMultiplier // ignore: cast_nullable_to_non_nullable
as double,playbackSpeed: null == playbackSpeed ? _self.playbackSpeed : playbackSpeed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [GifSetting].
extension GifSettingPatterns on GifSetting {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GifSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GifSetting value)  $default,){
final _that = this;
switch (_that) {
case _GifSetting():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GifSetting value)?  $default,){
final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fps,  int width,  int height,  Duration start,  Duration? end,  int loop,  int? frameDurationMs,  bool usePalette,  double scaleMultiplier,  double playbackSpeed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that.fps,_that.width,_that.height,_that.start,_that.end,_that.loop,_that.frameDurationMs,_that.usePalette,_that.scaleMultiplier,_that.playbackSpeed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fps,  int width,  int height,  Duration start,  Duration? end,  int loop,  int? frameDurationMs,  bool usePalette,  double scaleMultiplier,  double playbackSpeed)  $default,) {final _that = this;
switch (_that) {
case _GifSetting():
return $default(_that.fps,_that.width,_that.height,_that.start,_that.end,_that.loop,_that.frameDurationMs,_that.usePalette,_that.scaleMultiplier,_that.playbackSpeed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fps,  int width,  int height,  Duration start,  Duration? end,  int loop,  int? frameDurationMs,  bool usePalette,  double scaleMultiplier,  double playbackSpeed)?  $default,) {final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that.fps,_that.width,_that.height,_that.start,_that.end,_that.loop,_that.frameDurationMs,_that.usePalette,_that.scaleMultiplier,_that.playbackSpeed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GifSetting extends GifSetting {
  const _GifSetting({this.fps = 15.0, this.width = 0, this.height = 0, this.start = Duration.zero, this.end, this.loop = 0, this.frameDurationMs, this.usePalette = true, this.scaleMultiplier = 1.0, this.playbackSpeed = 1.0}): super._();
  factory _GifSetting.fromJson(Map<String, dynamic> json) => _$GifSettingFromJson(json);

/// 输出帧率(1–60)
@override@JsonKey() final  double fps;
/// 输出宽度(0 = 原图等比,默认)
@override@JsonKey() final  int width;
/// 输出高度(0 = 原图等比,默认;与宽度同时指定时按指定尺寸输出)
@override@JsonKey() final  int height;
/// 输出起点(相对源视频)
@override@JsonKey() final  Duration start;
/// 输出终点(默认取源视频时长,由导入时填充)
@override final  Duration? end;
/// 循环次数(0 = 无限循环)
@override@JsonKey() final  int loop;
/// 图片模式:每张图片停留时长(毫秒);null = 由 [fps] 推导(每图一帧)。
/// 视频模式不读取该字段。
@override final  int? frameDurationMs;
/// 图片模式:质量开关;true = 调色板两遍(高质,默认),false = 标准单遍。
/// 视频模式不读取该字段(视频 UI 无质量开关,恒走两遍)。
@override@JsonKey() final  bool usePalette;
/// 输出等比缩放倍数(0.5/0.75/1/1.5/2/3;1.0 = 不缩放,默认)。
///
/// 源尺寸已知时选倍数会联动落成具体 width/height;本字段是
/// "偏好/展开语义":批量入队时若 width==height==0 且 m!=1.0,
/// 按各视频自身尺寸 × m 展开(见 scale_multiplier.dart)。
@override@JsonKey() final  double scaleMultiplier;
/// 播放速度(0.25–4:0.25/0.5 慢放,1.0 正常,≥2 加速;默认 1.0)。
///
/// 命令侧经滤镜链 `setpts=PTS/<speed>` 实现:帧数不变、输出时间轴
/// 等比缩放(加速 → 总时长缩短,慢放 → 拉长);视频模式裁剪
/// `-ss`/`-to` 作用于源时间轴,不受速度影响;1.0 不注入滤镜(快照不变)。
@override@JsonKey() final  double playbackSpeed;

/// Create a copy of GifSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GifSettingCopyWith<_GifSetting> get copyWith => __$GifSettingCopyWithImpl<_GifSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GifSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GifSetting&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.loop, loop) || other.loop == loop)&&(identical(other.frameDurationMs, frameDurationMs) || other.frameDurationMs == frameDurationMs)&&(identical(other.usePalette, usePalette) || other.usePalette == usePalette)&&(identical(other.scaleMultiplier, scaleMultiplier) || other.scaleMultiplier == scaleMultiplier)&&(identical(other.playbackSpeed, playbackSpeed) || other.playbackSpeed == playbackSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,width,height,start,end,loop,frameDurationMs,usePalette,scaleMultiplier,playbackSpeed);

@override
String toString() {
  return 'GifSetting(fps: $fps, width: $width, height: $height, start: $start, end: $end, loop: $loop, frameDurationMs: $frameDurationMs, usePalette: $usePalette, scaleMultiplier: $scaleMultiplier, playbackSpeed: $playbackSpeed)';
}


}

/// @nodoc
abstract mixin class _$GifSettingCopyWith<$Res> implements $GifSettingCopyWith<$Res> {
  factory _$GifSettingCopyWith(_GifSetting value, $Res Function(_GifSetting) _then) = __$GifSettingCopyWithImpl;
@override @useResult
$Res call({
 double fps, int width, int height, Duration start, Duration? end, int loop, int? frameDurationMs, bool usePalette, double scaleMultiplier, double playbackSpeed
});




}
/// @nodoc
class __$GifSettingCopyWithImpl<$Res>
    implements _$GifSettingCopyWith<$Res> {
  __$GifSettingCopyWithImpl(this._self, this._then);

  final _GifSetting _self;
  final $Res Function(_GifSetting) _then;

/// Create a copy of GifSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fps = null,Object? width = null,Object? height = null,Object? start = null,Object? end = freezed,Object? loop = null,Object? frameDurationMs = freezed,Object? usePalette = null,Object? scaleMultiplier = null,Object? playbackSpeed = null,}) {
  return _then(_GifSetting(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as int,frameDurationMs: freezed == frameDurationMs ? _self.frameDurationMs : frameDurationMs // ignore: cast_nullable_to_non_nullable
as int?,usePalette: null == usePalette ? _self.usePalette : usePalette // ignore: cast_nullable_to_non_nullable
as bool,scaleMultiplier: null == scaleMultiplier ? _self.scaleMultiplier : scaleMultiplier // ignore: cast_nullable_to_non_nullable
as double,playbackSpeed: null == playbackSpeed ? _self.playbackSpeed : playbackSpeed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on

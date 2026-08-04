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
 int get width;/// 输出起点(相对源视频)
 Duration get start;/// 输出终点(默认取源视频时长,由导入时填充)
 Duration? get end;/// 循环次数(0 = 无限循环)
 int get loop;
/// Create a copy of GifSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GifSettingCopyWith<GifSetting> get copyWith => _$GifSettingCopyWithImpl<GifSetting>(this as GifSetting, _$identity);

  /// Serializes this GifSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GifSetting&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.loop, loop) || other.loop == loop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,width,start,end,loop);

@override
String toString() {
  return 'GifSetting(fps: $fps, width: $width, start: $start, end: $end, loop: $loop)';
}


}

/// @nodoc
abstract mixin class $GifSettingCopyWith<$Res>  {
  factory $GifSettingCopyWith(GifSetting value, $Res Function(GifSetting) _then) = _$GifSettingCopyWithImpl;
@useResult
$Res call({
 double fps, int width, Duration start, Duration? end, int loop
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
@pragma('vm:prefer-inline') @override $Res call({Object? fps = null,Object? width = null,Object? start = null,Object? end = freezed,Object? loop = null,}) {
  return _then(_self.copyWith(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fps,  int width,  Duration start,  Duration? end,  int loop)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that.fps,_that.width,_that.start,_that.end,_that.loop);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fps,  int width,  Duration start,  Duration? end,  int loop)  $default,) {final _that = this;
switch (_that) {
case _GifSetting():
return $default(_that.fps,_that.width,_that.start,_that.end,_that.loop);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fps,  int width,  Duration start,  Duration? end,  int loop)?  $default,) {final _that = this;
switch (_that) {
case _GifSetting() when $default != null:
return $default(_that.fps,_that.width,_that.start,_that.end,_that.loop);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GifSetting implements GifSetting {
  const _GifSetting({this.fps = 15.0, this.width = 0, this.start = Duration.zero, this.end, this.loop = 0});
  factory _GifSetting.fromJson(Map<String, dynamic> json) => _$GifSettingFromJson(json);

/// 输出帧率(1–60)
@override@JsonKey() final  double fps;
/// 输出宽度(0 = 原图等比,默认)
@override@JsonKey() final  int width;
/// 输出起点(相对源视频)
@override@JsonKey() final  Duration start;
/// 输出终点(默认取源视频时长,由导入时填充)
@override final  Duration? end;
/// 循环次数(0 = 无限循环)
@override@JsonKey() final  int loop;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GifSetting&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.width, width) || other.width == width)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.loop, loop) || other.loop == loop));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,width,start,end,loop);

@override
String toString() {
  return 'GifSetting(fps: $fps, width: $width, start: $start, end: $end, loop: $loop)';
}


}

/// @nodoc
abstract mixin class _$GifSettingCopyWith<$Res> implements $GifSettingCopyWith<$Res> {
  factory _$GifSettingCopyWith(_GifSetting value, $Res Function(_GifSetting) _then) = __$GifSettingCopyWithImpl;
@override @useResult
$Res call({
 double fps, int width, Duration start, Duration? end, int loop
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
@override @pragma('vm:prefer-inline') $Res call({Object? fps = null,Object? width = null,Object? start = null,Object? end = freezed,Object? loop = null,}) {
  return _then(_GifSetting(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration?,loop: null == loop ? _self.loop : loop // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

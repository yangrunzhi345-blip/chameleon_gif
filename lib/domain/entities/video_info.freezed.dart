// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoInfo {

/// 源文件绝对路径
 String get path;/// ffprobe format_name(如 "mov,mp4,m4a,3gp,3g2,mj2")
 String get formatName;/// 总时长
 Duration get duration;/// 首个视频流宽度
 int get width;/// 首个视频流高度
 int get height;/// 源帧率;部分编码器输出 0/0 时为 null
 double? get fps;/// 视频流 codec_name(如 "h264")
 String get codec;
/// Create a copy of VideoInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoInfoCopyWith<VideoInfo> get copyWith => _$VideoInfoCopyWithImpl<VideoInfo>(this as VideoInfo, _$identity);

  /// Serializes this VideoInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.formatName, formatName) || other.formatName == formatName)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.codec, codec) || other.codec == codec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,formatName,duration,width,height,fps,codec);

@override
String toString() {
  return 'VideoInfo(path: $path, formatName: $formatName, duration: $duration, width: $width, height: $height, fps: $fps, codec: $codec)';
}


}

/// @nodoc
abstract mixin class $VideoInfoCopyWith<$Res>  {
  factory $VideoInfoCopyWith(VideoInfo value, $Res Function(VideoInfo) _then) = _$VideoInfoCopyWithImpl;
@useResult
$Res call({
 String path, String formatName, Duration duration, int width, int height, double? fps, String codec
});




}
/// @nodoc
class _$VideoInfoCopyWithImpl<$Res>
    implements $VideoInfoCopyWith<$Res> {
  _$VideoInfoCopyWithImpl(this._self, this._then);

  final VideoInfo _self;
  final $Res Function(VideoInfo) _then;

/// Create a copy of VideoInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? formatName = null,Object? duration = null,Object? width = null,Object? height = null,Object? fps = freezed,Object? codec = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,formatName: null == formatName ? _self.formatName : formatName // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoInfo].
extension VideoInfoPatterns on VideoInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoInfo value)  $default,){
final _that = this;
switch (_that) {
case _VideoInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoInfo value)?  $default,){
final _that = this;
switch (_that) {
case _VideoInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String formatName,  Duration duration,  int width,  int height,  double? fps,  String codec)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoInfo() when $default != null:
return $default(_that.path,_that.formatName,_that.duration,_that.width,_that.height,_that.fps,_that.codec);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String formatName,  Duration duration,  int width,  int height,  double? fps,  String codec)  $default,) {final _that = this;
switch (_that) {
case _VideoInfo():
return $default(_that.path,_that.formatName,_that.duration,_that.width,_that.height,_that.fps,_that.codec);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String formatName,  Duration duration,  int width,  int height,  double? fps,  String codec)?  $default,) {final _that = this;
switch (_that) {
case _VideoInfo() when $default != null:
return $default(_that.path,_that.formatName,_that.duration,_that.width,_that.height,_that.fps,_that.codec);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoInfo implements VideoInfo {
  const _VideoInfo({required this.path, required this.formatName, required this.duration, required this.width, required this.height, this.fps, required this.codec});
  factory _VideoInfo.fromJson(Map<String, dynamic> json) => _$VideoInfoFromJson(json);

/// 源文件绝对路径
@override final  String path;
/// ffprobe format_name(如 "mov,mp4,m4a,3gp,3g2,mj2")
@override final  String formatName;
/// 总时长
@override final  Duration duration;
/// 首个视频流宽度
@override final  int width;
/// 首个视频流高度
@override final  int height;
/// 源帧率;部分编码器输出 0/0 时为 null
@override final  double? fps;
/// 视频流 codec_name(如 "h264")
@override final  String codec;

/// Create a copy of VideoInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoInfoCopyWith<_VideoInfo> get copyWith => __$VideoInfoCopyWithImpl<_VideoInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoInfo&&(identical(other.path, path) || other.path == path)&&(identical(other.formatName, formatName) || other.formatName == formatName)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.codec, codec) || other.codec == codec));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,formatName,duration,width,height,fps,codec);

@override
String toString() {
  return 'VideoInfo(path: $path, formatName: $formatName, duration: $duration, width: $width, height: $height, fps: $fps, codec: $codec)';
}


}

/// @nodoc
abstract mixin class _$VideoInfoCopyWith<$Res> implements $VideoInfoCopyWith<$Res> {
  factory _$VideoInfoCopyWith(_VideoInfo value, $Res Function(_VideoInfo) _then) = __$VideoInfoCopyWithImpl;
@override @useResult
$Res call({
 String path, String formatName, Duration duration, int width, int height, double? fps, String codec
});




}
/// @nodoc
class __$VideoInfoCopyWithImpl<$Res>
    implements _$VideoInfoCopyWith<$Res> {
  __$VideoInfoCopyWithImpl(this._self, this._then);

  final _VideoInfo _self;
  final $Res Function(_VideoInfo) _then;

/// Create a copy of VideoInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? formatName = null,Object? duration = null,Object? width = null,Object? height = null,Object? fps = freezed,Object? codec = null,}) {
  return _then(_VideoInfo(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,formatName: null == formatName ? _self.formatName : formatName // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,fps: freezed == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double?,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on

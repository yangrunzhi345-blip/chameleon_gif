// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'record_params.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecordParams {

/// 帧率(5–30)
 double get fps;/// 时长上限(毫秒,超时自动停)
 int get maxDurationMs;/// 区域模式(Windows gdigrab;Android 恒全屏)
 RecordRegion get regionMode;/// 窗口模式:目标窗口标题(gdigrab `title=`)
 String? get windowTitle;/// 自定义区域起点 X(gdigrab offset / x11grab `DISPLAY+x+y`)
 int? get regionX;/// 自定义区域起点 Y
 int? get regionY;/// 自定义区域宽度
 int? get regionWidth;/// 自定义区域高度
 int? get regionHeight;/// 是否显示光标(gdigrab 默认带;x11grab 需 `-draw_mouse`)
 bool get drawCursor;/// Android:虚拟显示比例(如 16/9);null = 全屏原生比例
 double? get aspectRatio;/// 桌面端:素材目录;null = 默认 capturesDir
 String? get outputDir;
/// Create a copy of RecordParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordParamsCopyWith<RecordParams> get copyWith => _$RecordParamsCopyWithImpl<RecordParams>(this as RecordParams, _$identity);

  /// Serializes this RecordParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordParams&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.maxDurationMs, maxDurationMs) || other.maxDurationMs == maxDurationMs)&&(identical(other.regionMode, regionMode) || other.regionMode == regionMode)&&(identical(other.windowTitle, windowTitle) || other.windowTitle == windowTitle)&&(identical(other.regionX, regionX) || other.regionX == regionX)&&(identical(other.regionY, regionY) || other.regionY == regionY)&&(identical(other.regionWidth, regionWidth) || other.regionWidth == regionWidth)&&(identical(other.regionHeight, regionHeight) || other.regionHeight == regionHeight)&&(identical(other.drawCursor, drawCursor) || other.drawCursor == drawCursor)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.outputDir, outputDir) || other.outputDir == outputDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,maxDurationMs,regionMode,windowTitle,regionX,regionY,regionWidth,regionHeight,drawCursor,aspectRatio,outputDir);

@override
String toString() {
  return 'RecordParams(fps: $fps, maxDurationMs: $maxDurationMs, regionMode: $regionMode, windowTitle: $windowTitle, regionX: $regionX, regionY: $regionY, regionWidth: $regionWidth, regionHeight: $regionHeight, drawCursor: $drawCursor, aspectRatio: $aspectRatio, outputDir: $outputDir)';
}


}

/// @nodoc
abstract mixin class $RecordParamsCopyWith<$Res>  {
  factory $RecordParamsCopyWith(RecordParams value, $Res Function(RecordParams) _then) = _$RecordParamsCopyWithImpl;
@useResult
$Res call({
 double fps, int maxDurationMs, RecordRegion regionMode, String? windowTitle, int? regionX, int? regionY, int? regionWidth, int? regionHeight, bool drawCursor, double? aspectRatio, String? outputDir
});




}
/// @nodoc
class _$RecordParamsCopyWithImpl<$Res>
    implements $RecordParamsCopyWith<$Res> {
  _$RecordParamsCopyWithImpl(this._self, this._then);

  final RecordParams _self;
  final $Res Function(RecordParams) _then;

/// Create a copy of RecordParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fps = null,Object? maxDurationMs = null,Object? regionMode = null,Object? windowTitle = freezed,Object? regionX = freezed,Object? regionY = freezed,Object? regionWidth = freezed,Object? regionHeight = freezed,Object? drawCursor = null,Object? aspectRatio = freezed,Object? outputDir = freezed,}) {
  return _then(_self.copyWith(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,maxDurationMs: null == maxDurationMs ? _self.maxDurationMs : maxDurationMs // ignore: cast_nullable_to_non_nullable
as int,regionMode: null == regionMode ? _self.regionMode : regionMode // ignore: cast_nullable_to_non_nullable
as RecordRegion,windowTitle: freezed == windowTitle ? _self.windowTitle : windowTitle // ignore: cast_nullable_to_non_nullable
as String?,regionX: freezed == regionX ? _self.regionX : regionX // ignore: cast_nullable_to_non_nullable
as int?,regionY: freezed == regionY ? _self.regionY : regionY // ignore: cast_nullable_to_non_nullable
as int?,regionWidth: freezed == regionWidth ? _self.regionWidth : regionWidth // ignore: cast_nullable_to_non_nullable
as int?,regionHeight: freezed == regionHeight ? _self.regionHeight : regionHeight // ignore: cast_nullable_to_non_nullable
as int?,drawCursor: null == drawCursor ? _self.drawCursor : drawCursor // ignore: cast_nullable_to_non_nullable
as bool,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,outputDir: freezed == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RecordParams].
extension RecordParamsPatterns on RecordParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecordParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecordParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecordParams value)  $default,){
final _that = this;
switch (_that) {
case _RecordParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecordParams value)?  $default,){
final _that = this;
switch (_that) {
case _RecordParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double fps,  int maxDurationMs,  RecordRegion regionMode,  String? windowTitle,  int? regionX,  int? regionY,  int? regionWidth,  int? regionHeight,  bool drawCursor,  double? aspectRatio,  String? outputDir)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecordParams() when $default != null:
return $default(_that.fps,_that.maxDurationMs,_that.regionMode,_that.windowTitle,_that.regionX,_that.regionY,_that.regionWidth,_that.regionHeight,_that.drawCursor,_that.aspectRatio,_that.outputDir);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double fps,  int maxDurationMs,  RecordRegion regionMode,  String? windowTitle,  int? regionX,  int? regionY,  int? regionWidth,  int? regionHeight,  bool drawCursor,  double? aspectRatio,  String? outputDir)  $default,) {final _that = this;
switch (_that) {
case _RecordParams():
return $default(_that.fps,_that.maxDurationMs,_that.regionMode,_that.windowTitle,_that.regionX,_that.regionY,_that.regionWidth,_that.regionHeight,_that.drawCursor,_that.aspectRatio,_that.outputDir);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double fps,  int maxDurationMs,  RecordRegion regionMode,  String? windowTitle,  int? regionX,  int? regionY,  int? regionWidth,  int? regionHeight,  bool drawCursor,  double? aspectRatio,  String? outputDir)?  $default,) {final _that = this;
switch (_that) {
case _RecordParams() when $default != null:
return $default(_that.fps,_that.maxDurationMs,_that.regionMode,_that.windowTitle,_that.regionX,_that.regionY,_that.regionWidth,_that.regionHeight,_that.drawCursor,_that.aspectRatio,_that.outputDir);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecordParams extends RecordParams {
  const _RecordParams({this.fps = 15.0, this.maxDurationMs = 60000, this.regionMode = RecordRegion.fullscreen, this.windowTitle, this.regionX, this.regionY, this.regionWidth, this.regionHeight, this.drawCursor = true, this.aspectRatio, this.outputDir}): super._();
  factory _RecordParams.fromJson(Map<String, dynamic> json) => _$RecordParamsFromJson(json);

/// 帧率(5–30)
@override@JsonKey() final  double fps;
/// 时长上限(毫秒,超时自动停)
@override@JsonKey() final  int maxDurationMs;
/// 区域模式(Windows gdigrab;Android 恒全屏)
@override@JsonKey() final  RecordRegion regionMode;
/// 窗口模式:目标窗口标题(gdigrab `title=`)
@override final  String? windowTitle;
/// 自定义区域起点 X(gdigrab offset / x11grab `DISPLAY+x+y`)
@override final  int? regionX;
/// 自定义区域起点 Y
@override final  int? regionY;
/// 自定义区域宽度
@override final  int? regionWidth;
/// 自定义区域高度
@override final  int? regionHeight;
/// 是否显示光标(gdigrab 默认带;x11grab 需 `-draw_mouse`)
@override@JsonKey() final  bool drawCursor;
/// Android:虚拟显示比例(如 16/9);null = 全屏原生比例
@override final  double? aspectRatio;
/// 桌面端:素材目录;null = 默认 capturesDir
@override final  String? outputDir;

/// Create a copy of RecordParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecordParamsCopyWith<_RecordParams> get copyWith => __$RecordParamsCopyWithImpl<_RecordParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecordParamsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecordParams&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.maxDurationMs, maxDurationMs) || other.maxDurationMs == maxDurationMs)&&(identical(other.regionMode, regionMode) || other.regionMode == regionMode)&&(identical(other.windowTitle, windowTitle) || other.windowTitle == windowTitle)&&(identical(other.regionX, regionX) || other.regionX == regionX)&&(identical(other.regionY, regionY) || other.regionY == regionY)&&(identical(other.regionWidth, regionWidth) || other.regionWidth == regionWidth)&&(identical(other.regionHeight, regionHeight) || other.regionHeight == regionHeight)&&(identical(other.drawCursor, drawCursor) || other.drawCursor == drawCursor)&&(identical(other.aspectRatio, aspectRatio) || other.aspectRatio == aspectRatio)&&(identical(other.outputDir, outputDir) || other.outputDir == outputDir));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fps,maxDurationMs,regionMode,windowTitle,regionX,regionY,regionWidth,regionHeight,drawCursor,aspectRatio,outputDir);

@override
String toString() {
  return 'RecordParams(fps: $fps, maxDurationMs: $maxDurationMs, regionMode: $regionMode, windowTitle: $windowTitle, regionX: $regionX, regionY: $regionY, regionWidth: $regionWidth, regionHeight: $regionHeight, drawCursor: $drawCursor, aspectRatio: $aspectRatio, outputDir: $outputDir)';
}


}

/// @nodoc
abstract mixin class _$RecordParamsCopyWith<$Res> implements $RecordParamsCopyWith<$Res> {
  factory _$RecordParamsCopyWith(_RecordParams value, $Res Function(_RecordParams) _then) = __$RecordParamsCopyWithImpl;
@override @useResult
$Res call({
 double fps, int maxDurationMs, RecordRegion regionMode, String? windowTitle, int? regionX, int? regionY, int? regionWidth, int? regionHeight, bool drawCursor, double? aspectRatio, String? outputDir
});




}
/// @nodoc
class __$RecordParamsCopyWithImpl<$Res>
    implements _$RecordParamsCopyWith<$Res> {
  __$RecordParamsCopyWithImpl(this._self, this._then);

  final _RecordParams _self;
  final $Res Function(_RecordParams) _then;

/// Create a copy of RecordParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fps = null,Object? maxDurationMs = null,Object? regionMode = null,Object? windowTitle = freezed,Object? regionX = freezed,Object? regionY = freezed,Object? regionWidth = freezed,Object? regionHeight = freezed,Object? drawCursor = null,Object? aspectRatio = freezed,Object? outputDir = freezed,}) {
  return _then(_RecordParams(
fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,maxDurationMs: null == maxDurationMs ? _self.maxDurationMs : maxDurationMs // ignore: cast_nullable_to_non_nullable
as int,regionMode: null == regionMode ? _self.regionMode : regionMode // ignore: cast_nullable_to_non_nullable
as RecordRegion,windowTitle: freezed == windowTitle ? _self.windowTitle : windowTitle // ignore: cast_nullable_to_non_nullable
as String?,regionX: freezed == regionX ? _self.regionX : regionX // ignore: cast_nullable_to_non_nullable
as int?,regionY: freezed == regionY ? _self.regionY : regionY // ignore: cast_nullable_to_non_nullable
as int?,regionWidth: freezed == regionWidth ? _self.regionWidth : regionWidth // ignore: cast_nullable_to_non_nullable
as int?,regionHeight: freezed == regionHeight ? _self.regionHeight : regionHeight // ignore: cast_nullable_to_non_nullable
as int?,drawCursor: null == drawCursor ? _self.drawCursor : drawCursor // ignore: cast_nullable_to_non_nullable
as bool,aspectRatio: freezed == aspectRatio ? _self.aspectRatio : aspectRatio // ignore: cast_nullable_to_non_nullable
as double?,outputDir: freezed == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

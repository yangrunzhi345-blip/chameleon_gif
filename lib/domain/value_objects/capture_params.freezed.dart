// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'capture_params.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CaptureParams {

/// 目标设备标识(null = 默认后置摄像头;Android 前后摄,桌面 /dev/videoN)
 String? get deviceId;/// 帧率(1–60)
 double get fps;/// 桌面端:采集分辨率宽度;Android 忽略
 int? get resolutionWidth;/// 桌面端:采集分辨率高度;Android 忽略
 int? get resolutionHeight;/// 时长上限(毫秒,超时自动停)
 int get maxDurationMs;/// 白平衡色温(K)
 int? get whiteBalanceTemp;/// 白平衡自动(默认开,与相机自动白平衡默认态一致)
 bool get whiteBalanceAuto;/// 曝光补偿
 double? get exposureCompensation;/// 曝光锁定
 bool get exposureLock;/// ISO 感光度
 int? get iso;/// 对焦模式
 FocusMode get focusMode;/// 变焦倍数
 double? get zoom;/// 闪光灯
 bool get flashOn;/// 桌面端:素材目录;null = 默认 capturesDir
 String? get outputDir;/// 桌面端第二档控制项(v4l2-ctl 语义:控制名 → 目标值,如
/// {'brightness': 10};由设置页动态面板生成;Android 忽略)。
/// 空 map 表示不调整(设备保持当前值)。
 Map<String, int> get v4l2Controls;
/// Create a copy of CaptureParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CaptureParamsCopyWith<CaptureParams> get copyWith => _$CaptureParamsCopyWithImpl<CaptureParams>(this as CaptureParams, _$identity);

  /// Serializes this CaptureParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CaptureParams&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.resolutionWidth, resolutionWidth) || other.resolutionWidth == resolutionWidth)&&(identical(other.resolutionHeight, resolutionHeight) || other.resolutionHeight == resolutionHeight)&&(identical(other.maxDurationMs, maxDurationMs) || other.maxDurationMs == maxDurationMs)&&(identical(other.whiteBalanceTemp, whiteBalanceTemp) || other.whiteBalanceTemp == whiteBalanceTemp)&&(identical(other.whiteBalanceAuto, whiteBalanceAuto) || other.whiteBalanceAuto == whiteBalanceAuto)&&(identical(other.exposureCompensation, exposureCompensation) || other.exposureCompensation == exposureCompensation)&&(identical(other.exposureLock, exposureLock) || other.exposureLock == exposureLock)&&(identical(other.iso, iso) || other.iso == iso)&&(identical(other.focusMode, focusMode) || other.focusMode == focusMode)&&(identical(other.zoom, zoom) || other.zoom == zoom)&&(identical(other.flashOn, flashOn) || other.flashOn == flashOn)&&(identical(other.outputDir, outputDir) || other.outputDir == outputDir)&&const DeepCollectionEquality().equals(other.v4l2Controls, v4l2Controls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,fps,resolutionWidth,resolutionHeight,maxDurationMs,whiteBalanceTemp,whiteBalanceAuto,exposureCompensation,exposureLock,iso,focusMode,zoom,flashOn,outputDir,const DeepCollectionEquality().hash(v4l2Controls));

@override
String toString() {
  return 'CaptureParams(deviceId: $deviceId, fps: $fps, resolutionWidth: $resolutionWidth, resolutionHeight: $resolutionHeight, maxDurationMs: $maxDurationMs, whiteBalanceTemp: $whiteBalanceTemp, whiteBalanceAuto: $whiteBalanceAuto, exposureCompensation: $exposureCompensation, exposureLock: $exposureLock, iso: $iso, focusMode: $focusMode, zoom: $zoom, flashOn: $flashOn, outputDir: $outputDir, v4l2Controls: $v4l2Controls)';
}


}

/// @nodoc
abstract mixin class $CaptureParamsCopyWith<$Res>  {
  factory $CaptureParamsCopyWith(CaptureParams value, $Res Function(CaptureParams) _then) = _$CaptureParamsCopyWithImpl;
@useResult
$Res call({
 String? deviceId, double fps, int? resolutionWidth, int? resolutionHeight, int maxDurationMs, int? whiteBalanceTemp, bool whiteBalanceAuto, double? exposureCompensation, bool exposureLock, int? iso, FocusMode focusMode, double? zoom, bool flashOn, String? outputDir, Map<String, int> v4l2Controls
});




}
/// @nodoc
class _$CaptureParamsCopyWithImpl<$Res>
    implements $CaptureParamsCopyWith<$Res> {
  _$CaptureParamsCopyWithImpl(this._self, this._then);

  final CaptureParams _self;
  final $Res Function(CaptureParams) _then;

/// Create a copy of CaptureParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = freezed,Object? fps = null,Object? resolutionWidth = freezed,Object? resolutionHeight = freezed,Object? maxDurationMs = null,Object? whiteBalanceTemp = freezed,Object? whiteBalanceAuto = null,Object? exposureCompensation = freezed,Object? exposureLock = null,Object? iso = freezed,Object? focusMode = null,Object? zoom = freezed,Object? flashOn = null,Object? outputDir = freezed,Object? v4l2Controls = null,}) {
  return _then(_self.copyWith(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,resolutionWidth: freezed == resolutionWidth ? _self.resolutionWidth : resolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,resolutionHeight: freezed == resolutionHeight ? _self.resolutionHeight : resolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,maxDurationMs: null == maxDurationMs ? _self.maxDurationMs : maxDurationMs // ignore: cast_nullable_to_non_nullable
as int,whiteBalanceTemp: freezed == whiteBalanceTemp ? _self.whiteBalanceTemp : whiteBalanceTemp // ignore: cast_nullable_to_non_nullable
as int?,whiteBalanceAuto: null == whiteBalanceAuto ? _self.whiteBalanceAuto : whiteBalanceAuto // ignore: cast_nullable_to_non_nullable
as bool,exposureCompensation: freezed == exposureCompensation ? _self.exposureCompensation : exposureCompensation // ignore: cast_nullable_to_non_nullable
as double?,exposureLock: null == exposureLock ? _self.exposureLock : exposureLock // ignore: cast_nullable_to_non_nullable
as bool,iso: freezed == iso ? _self.iso : iso // ignore: cast_nullable_to_non_nullable
as int?,focusMode: null == focusMode ? _self.focusMode : focusMode // ignore: cast_nullable_to_non_nullable
as FocusMode,zoom: freezed == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double?,flashOn: null == flashOn ? _self.flashOn : flashOn // ignore: cast_nullable_to_non_nullable
as bool,outputDir: freezed == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String?,v4l2Controls: null == v4l2Controls ? _self.v4l2Controls : v4l2Controls // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [CaptureParams].
extension CaptureParamsPatterns on CaptureParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CaptureParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CaptureParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CaptureParams value)  $default,){
final _that = this;
switch (_that) {
case _CaptureParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CaptureParams value)?  $default,){
final _that = this;
switch (_that) {
case _CaptureParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? deviceId,  double fps,  int? resolutionWidth,  int? resolutionHeight,  int maxDurationMs,  int? whiteBalanceTemp,  bool whiteBalanceAuto,  double? exposureCompensation,  bool exposureLock,  int? iso,  FocusMode focusMode,  double? zoom,  bool flashOn,  String? outputDir,  Map<String, int> v4l2Controls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CaptureParams() when $default != null:
return $default(_that.deviceId,_that.fps,_that.resolutionWidth,_that.resolutionHeight,_that.maxDurationMs,_that.whiteBalanceTemp,_that.whiteBalanceAuto,_that.exposureCompensation,_that.exposureLock,_that.iso,_that.focusMode,_that.zoom,_that.flashOn,_that.outputDir,_that.v4l2Controls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? deviceId,  double fps,  int? resolutionWidth,  int? resolutionHeight,  int maxDurationMs,  int? whiteBalanceTemp,  bool whiteBalanceAuto,  double? exposureCompensation,  bool exposureLock,  int? iso,  FocusMode focusMode,  double? zoom,  bool flashOn,  String? outputDir,  Map<String, int> v4l2Controls)  $default,) {final _that = this;
switch (_that) {
case _CaptureParams():
return $default(_that.deviceId,_that.fps,_that.resolutionWidth,_that.resolutionHeight,_that.maxDurationMs,_that.whiteBalanceTemp,_that.whiteBalanceAuto,_that.exposureCompensation,_that.exposureLock,_that.iso,_that.focusMode,_that.zoom,_that.flashOn,_that.outputDir,_that.v4l2Controls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? deviceId,  double fps,  int? resolutionWidth,  int? resolutionHeight,  int maxDurationMs,  int? whiteBalanceTemp,  bool whiteBalanceAuto,  double? exposureCompensation,  bool exposureLock,  int? iso,  FocusMode focusMode,  double? zoom,  bool flashOn,  String? outputDir,  Map<String, int> v4l2Controls)?  $default,) {final _that = this;
switch (_that) {
case _CaptureParams() when $default != null:
return $default(_that.deviceId,_that.fps,_that.resolutionWidth,_that.resolutionHeight,_that.maxDurationMs,_that.whiteBalanceTemp,_that.whiteBalanceAuto,_that.exposureCompensation,_that.exposureLock,_that.iso,_that.focusMode,_that.zoom,_that.flashOn,_that.outputDir,_that.v4l2Controls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CaptureParams extends CaptureParams {
  const _CaptureParams({this.deviceId, this.fps = 15.0, this.resolutionWidth, this.resolutionHeight, this.maxDurationMs = 30000, this.whiteBalanceTemp, this.whiteBalanceAuto = true, this.exposureCompensation, this.exposureLock = false, this.iso, this.focusMode = FocusMode.auto, this.zoom, this.flashOn = false, this.outputDir, final  Map<String, int> v4l2Controls = const <String, int>{}}): _v4l2Controls = v4l2Controls,super._();
  factory _CaptureParams.fromJson(Map<String, dynamic> json) => _$CaptureParamsFromJson(json);

/// 目标设备标识(null = 默认后置摄像头;Android 前后摄,桌面 /dev/videoN)
@override final  String? deviceId;
/// 帧率(1–60)
@override@JsonKey() final  double fps;
/// 桌面端:采集分辨率宽度;Android 忽略
@override final  int? resolutionWidth;
/// 桌面端:采集分辨率高度;Android 忽略
@override final  int? resolutionHeight;
/// 时长上限(毫秒,超时自动停)
@override@JsonKey() final  int maxDurationMs;
/// 白平衡色温(K)
@override final  int? whiteBalanceTemp;
/// 白平衡自动(默认开,与相机自动白平衡默认态一致)
@override@JsonKey() final  bool whiteBalanceAuto;
/// 曝光补偿
@override final  double? exposureCompensation;
/// 曝光锁定
@override@JsonKey() final  bool exposureLock;
/// ISO 感光度
@override final  int? iso;
/// 对焦模式
@override@JsonKey() final  FocusMode focusMode;
/// 变焦倍数
@override final  double? zoom;
/// 闪光灯
@override@JsonKey() final  bool flashOn;
/// 桌面端:素材目录;null = 默认 capturesDir
@override final  String? outputDir;
/// 桌面端第二档控制项(v4l2-ctl 语义:控制名 → 目标值,如
/// {'brightness': 10};由设置页动态面板生成;Android 忽略)。
/// 空 map 表示不调整(设备保持当前值)。
 final  Map<String, int> _v4l2Controls;
/// 桌面端第二档控制项(v4l2-ctl 语义:控制名 → 目标值,如
/// {'brightness': 10};由设置页动态面板生成;Android 忽略)。
/// 空 map 表示不调整(设备保持当前值)。
@override@JsonKey() Map<String, int> get v4l2Controls {
  if (_v4l2Controls is EqualUnmodifiableMapView) return _v4l2Controls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_v4l2Controls);
}


/// Create a copy of CaptureParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CaptureParamsCopyWith<_CaptureParams> get copyWith => __$CaptureParamsCopyWithImpl<_CaptureParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CaptureParamsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CaptureParams&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.fps, fps) || other.fps == fps)&&(identical(other.resolutionWidth, resolutionWidth) || other.resolutionWidth == resolutionWidth)&&(identical(other.resolutionHeight, resolutionHeight) || other.resolutionHeight == resolutionHeight)&&(identical(other.maxDurationMs, maxDurationMs) || other.maxDurationMs == maxDurationMs)&&(identical(other.whiteBalanceTemp, whiteBalanceTemp) || other.whiteBalanceTemp == whiteBalanceTemp)&&(identical(other.whiteBalanceAuto, whiteBalanceAuto) || other.whiteBalanceAuto == whiteBalanceAuto)&&(identical(other.exposureCompensation, exposureCompensation) || other.exposureCompensation == exposureCompensation)&&(identical(other.exposureLock, exposureLock) || other.exposureLock == exposureLock)&&(identical(other.iso, iso) || other.iso == iso)&&(identical(other.focusMode, focusMode) || other.focusMode == focusMode)&&(identical(other.zoom, zoom) || other.zoom == zoom)&&(identical(other.flashOn, flashOn) || other.flashOn == flashOn)&&(identical(other.outputDir, outputDir) || other.outputDir == outputDir)&&const DeepCollectionEquality().equals(other._v4l2Controls, _v4l2Controls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,fps,resolutionWidth,resolutionHeight,maxDurationMs,whiteBalanceTemp,whiteBalanceAuto,exposureCompensation,exposureLock,iso,focusMode,zoom,flashOn,outputDir,const DeepCollectionEquality().hash(_v4l2Controls));

@override
String toString() {
  return 'CaptureParams(deviceId: $deviceId, fps: $fps, resolutionWidth: $resolutionWidth, resolutionHeight: $resolutionHeight, maxDurationMs: $maxDurationMs, whiteBalanceTemp: $whiteBalanceTemp, whiteBalanceAuto: $whiteBalanceAuto, exposureCompensation: $exposureCompensation, exposureLock: $exposureLock, iso: $iso, focusMode: $focusMode, zoom: $zoom, flashOn: $flashOn, outputDir: $outputDir, v4l2Controls: $v4l2Controls)';
}


}

/// @nodoc
abstract mixin class _$CaptureParamsCopyWith<$Res> implements $CaptureParamsCopyWith<$Res> {
  factory _$CaptureParamsCopyWith(_CaptureParams value, $Res Function(_CaptureParams) _then) = __$CaptureParamsCopyWithImpl;
@override @useResult
$Res call({
 String? deviceId, double fps, int? resolutionWidth, int? resolutionHeight, int maxDurationMs, int? whiteBalanceTemp, bool whiteBalanceAuto, double? exposureCompensation, bool exposureLock, int? iso, FocusMode focusMode, double? zoom, bool flashOn, String? outputDir, Map<String, int> v4l2Controls
});




}
/// @nodoc
class __$CaptureParamsCopyWithImpl<$Res>
    implements _$CaptureParamsCopyWith<$Res> {
  __$CaptureParamsCopyWithImpl(this._self, this._then);

  final _CaptureParams _self;
  final $Res Function(_CaptureParams) _then;

/// Create a copy of CaptureParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = freezed,Object? fps = null,Object? resolutionWidth = freezed,Object? resolutionHeight = freezed,Object? maxDurationMs = null,Object? whiteBalanceTemp = freezed,Object? whiteBalanceAuto = null,Object? exposureCompensation = freezed,Object? exposureLock = null,Object? iso = freezed,Object? focusMode = null,Object? zoom = freezed,Object? flashOn = null,Object? outputDir = freezed,Object? v4l2Controls = null,}) {
  return _then(_CaptureParams(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,fps: null == fps ? _self.fps : fps // ignore: cast_nullable_to_non_nullable
as double,resolutionWidth: freezed == resolutionWidth ? _self.resolutionWidth : resolutionWidth // ignore: cast_nullable_to_non_nullable
as int?,resolutionHeight: freezed == resolutionHeight ? _self.resolutionHeight : resolutionHeight // ignore: cast_nullable_to_non_nullable
as int?,maxDurationMs: null == maxDurationMs ? _self.maxDurationMs : maxDurationMs // ignore: cast_nullable_to_non_nullable
as int,whiteBalanceTemp: freezed == whiteBalanceTemp ? _self.whiteBalanceTemp : whiteBalanceTemp // ignore: cast_nullable_to_non_nullable
as int?,whiteBalanceAuto: null == whiteBalanceAuto ? _self.whiteBalanceAuto : whiteBalanceAuto // ignore: cast_nullable_to_non_nullable
as bool,exposureCompensation: freezed == exposureCompensation ? _self.exposureCompensation : exposureCompensation // ignore: cast_nullable_to_non_nullable
as double?,exposureLock: null == exposureLock ? _self.exposureLock : exposureLock // ignore: cast_nullable_to_non_nullable
as bool,iso: freezed == iso ? _self.iso : iso // ignore: cast_nullable_to_non_nullable
as int?,focusMode: null == focusMode ? _self.focusMode : focusMode // ignore: cast_nullable_to_non_nullable
as FocusMode,zoom: freezed == zoom ? _self.zoom : zoom // ignore: cast_nullable_to_non_nullable
as double?,flashOn: null == flashOn ? _self.flashOn : flashOn // ignore: cast_nullable_to_non_nullable
as bool,outputDir: freezed == outputDir ? _self.outputDir : outputDir // ignore: cast_nullable_to_non_nullable
as String?,v4l2Controls: null == v4l2Controls ? _self._v4l2Controls : v4l2Controls // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}

// dart format on

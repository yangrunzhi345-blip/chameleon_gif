// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'per_image_control.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PerImageControl {

/// 等比缩放倍数(仅宽高均 0 时生效;0.1–4,默认 1.0)
 double get scaleMultiplier;/// 目标宽度(0 = 不指定,按自身比例;默认)
 int get width;/// 目标高度(0 = 不指定,按自身比例;默认)
 int get height;
/// Create a copy of PerImageControl
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PerImageControlCopyWith<PerImageControl> get copyWith => _$PerImageControlCopyWithImpl<PerImageControl>(this as PerImageControl, _$identity);

  /// Serializes this PerImageControl to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PerImageControl&&(identical(other.scaleMultiplier, scaleMultiplier) || other.scaleMultiplier == scaleMultiplier)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scaleMultiplier,width,height);

@override
String toString() {
  return 'PerImageControl(scaleMultiplier: $scaleMultiplier, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $PerImageControlCopyWith<$Res>  {
  factory $PerImageControlCopyWith(PerImageControl value, $Res Function(PerImageControl) _then) = _$PerImageControlCopyWithImpl;
@useResult
$Res call({
 double scaleMultiplier, int width, int height
});




}
/// @nodoc
class _$PerImageControlCopyWithImpl<$Res>
    implements $PerImageControlCopyWith<$Res> {
  _$PerImageControlCopyWithImpl(this._self, this._then);

  final PerImageControl _self;
  final $Res Function(PerImageControl) _then;

/// Create a copy of PerImageControl
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scaleMultiplier = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
scaleMultiplier: null == scaleMultiplier ? _self.scaleMultiplier : scaleMultiplier // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PerImageControl].
extension PerImageControlPatterns on PerImageControl {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PerImageControl value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PerImageControl() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PerImageControl value)  $default,){
final _that = this;
switch (_that) {
case _PerImageControl():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PerImageControl value)?  $default,){
final _that = this;
switch (_that) {
case _PerImageControl() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double scaleMultiplier,  int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PerImageControl() when $default != null:
return $default(_that.scaleMultiplier,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double scaleMultiplier,  int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _PerImageControl():
return $default(_that.scaleMultiplier,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double scaleMultiplier,  int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _PerImageControl() when $default != null:
return $default(_that.scaleMultiplier,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PerImageControl extends PerImageControl {
  const _PerImageControl({this.scaleMultiplier = 1.0, this.width = 0, this.height = 0}): super._();
  factory _PerImageControl.fromJson(Map<String, dynamic> json) => _$PerImageControlFromJson(json);

/// 等比缩放倍数(仅宽高均 0 时生效;0.1–4,默认 1.0)
@override@JsonKey() final  double scaleMultiplier;
/// 目标宽度(0 = 不指定,按自身比例;默认)
@override@JsonKey() final  int width;
/// 目标高度(0 = 不指定,按自身比例;默认)
@override@JsonKey() final  int height;

/// Create a copy of PerImageControl
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PerImageControlCopyWith<_PerImageControl> get copyWith => __$PerImageControlCopyWithImpl<_PerImageControl>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PerImageControlToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PerImageControl&&(identical(other.scaleMultiplier, scaleMultiplier) || other.scaleMultiplier == scaleMultiplier)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,scaleMultiplier,width,height);

@override
String toString() {
  return 'PerImageControl(scaleMultiplier: $scaleMultiplier, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$PerImageControlCopyWith<$Res> implements $PerImageControlCopyWith<$Res> {
  factory _$PerImageControlCopyWith(_PerImageControl value, $Res Function(_PerImageControl) _then) = __$PerImageControlCopyWithImpl;
@override @useResult
$Res call({
 double scaleMultiplier, int width, int height
});




}
/// @nodoc
class __$PerImageControlCopyWithImpl<$Res>
    implements _$PerImageControlCopyWith<$Res> {
  __$PerImageControlCopyWithImpl(this._self, this._then);

  final _PerImageControl _self;
  final $Res Function(_PerImageControl) _then;

/// Create a copy of PerImageControl
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scaleMultiplier = null,Object? width = null,Object? height = null,}) {
  return _then(_PerImageControl(
scaleMultiplier: null == scaleMultiplier ? _self.scaleMultiplier : scaleMultiplier // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on

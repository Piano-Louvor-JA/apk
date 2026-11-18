// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'custom_liturgy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CustomLiturgy {

 String get id; String get name; List<LiturgyItem> get items; String get notes; String? get startTime; String? get endTime;
/// Create a copy of CustomLiturgy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomLiturgyCopyWith<CustomLiturgy> get copyWith => _$CustomLiturgyCopyWithImpl<CustomLiturgy>(this as CustomLiturgy, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CustomLiturgy;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomLiturgy&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.startTime, _this.startTime) || other.startTime == _this.startTime)&&(identical(other.endTime, _this.endTime) || other.endTime == _this.endTime));
}


@override
int get hashCode {
  final _this = this as CustomLiturgy;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.items),_this.notes,_this.startTime,_this.endTime);
}

@override
String toString() {
  final _this = this as CustomLiturgy;
  return 'CustomLiturgy(id: ${_this.id}, name: ${_this.name}, items: ${_this.items}, notes: ${_this.notes}, startTime: ${_this.startTime}, endTime: ${_this.endTime})';
}


}

/// @nodoc
abstract mixin class $CustomLiturgyCopyWith<$Res>  {
  factory $CustomLiturgyCopyWith(CustomLiturgy value, $Res Function(CustomLiturgy) _then) = _$CustomLiturgyCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<LiturgyItem> items, String notes, String? startTime, String? endTime
});




}
/// @nodoc
class _$CustomLiturgyCopyWithImpl<$Res>
    implements $CustomLiturgyCopyWith<$Res> {
  _$CustomLiturgyCopyWithImpl(this._self, this._then);

  final CustomLiturgy _self;
  final $Res Function(CustomLiturgy) _then;

/// Create a copy of CustomLiturgy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? items = null,Object? notes = null,Object? startTime = freezed,Object? endTime = freezed,}) {
  return _then(CustomLiturgy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<LiturgyItem>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomLiturgy].
extension CustomLiturgyPatterns on CustomLiturgy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomLiturgy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomLiturgy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomLiturgy value)  $default,){
final _that = this;
switch (_that) {
case _CustomLiturgy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomLiturgy value)?  $default,){
final _that = this;
switch (_that) {
case _CustomLiturgy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  List<LiturgyItem> items,  String notes,  String? startTime,  String? endTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomLiturgy() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.notes,_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  List<LiturgyItem> items,  String notes,  String? startTime,  String? endTime)  $default,) {final _that = this;
switch (_that) {
case _CustomLiturgy():
return $default(_that.id,_that.name,_that.items,_that.notes,_that.startTime,_that.endTime);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  List<LiturgyItem> items,  String notes,  String? startTime,  String? endTime)?  $default,) {final _that = this;
switch (_that) {
case _CustomLiturgy() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.notes,_that.startTime,_that.endTime);case _:
  return null;

}
}

}

/// @nodoc


class _CustomLiturgy extends CustomLiturgy {
  const _CustomLiturgy({required this.id, required this.name,  List<LiturgyItem> items = const [], this.notes = '', this.startTime, this.endTime}): _items = items,super._();


@override final  String id;
@override final  String name;
 final  List<LiturgyItem> _items;
@override@JsonKey() List<LiturgyItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  String notes;
@override final  String? startTime;
@override final  String? endTime;

/// Create a copy of CustomLiturgy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomLiturgyCopyWith<_CustomLiturgy> get copyWith => __$CustomLiturgyCopyWithImpl<_CustomLiturgy>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomLiturgy&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_items),notes,startTime,endTime);
}

@override
String toString() {
    return 'CustomLiturgy(id: $id, name: $name, items: $items, notes: $notes, startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class _$CustomLiturgyCopyWith<$Res> implements $CustomLiturgyCopyWith<$Res> {
  factory _$CustomLiturgyCopyWith(_CustomLiturgy value, $Res Function(_CustomLiturgy) _then) = __$CustomLiturgyCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<LiturgyItem> items, String notes, String? startTime, String? endTime
});




}
/// @nodoc
class __$CustomLiturgyCopyWithImpl<$Res>
    implements _$CustomLiturgyCopyWith<$Res> {
  __$CustomLiturgyCopyWithImpl(this._self, this._then);

  final _CustomLiturgy _self;
  final $Res Function(_CustomLiturgy) _then;

/// Create a copy of CustomLiturgy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? items = null,Object? notes = null,Object? startTime = freezed,Object? endTime = freezed,}) {
  return _then(_CustomLiturgy(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<LiturgyItem>,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on

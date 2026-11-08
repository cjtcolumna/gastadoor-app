// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Subscription {

 String get id; String get userId; String get name;/// What each charge costs, in cents.
 int get amountCents; SubscriptionFrequency get frequency;/// The date the schedule is counted from (the "Next charge" date picked
/// in the form). Set by you; never changes by itself.
 DateTime get firstChargeOn;/// When the next expense will be added. The database keeps this right.
 DateTime get nextChargeOn;/// The account that pays for it.
 String get accountId; String? get categoryId;/// False = paused: nothing is charged until you resume.
 bool get active; DateTime? get createdAt;
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<Subscription> get copyWith => _$SubscriptionCopyWithImpl<Subscription>(this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Subscription;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subscription&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.amountCents, _this.amountCents) || other.amountCents == _this.amountCents)&&(identical(other.frequency, _this.frequency) || other.frequency == _this.frequency)&&(identical(other.firstChargeOn, _this.firstChargeOn) || other.firstChargeOn == _this.firstChargeOn)&&(identical(other.nextChargeOn, _this.nextChargeOn) || other.nextChargeOn == _this.nextChargeOn)&&(identical(other.accountId, _this.accountId) || other.accountId == _this.accountId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Subscription;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.name,_this.amountCents,_this.frequency,_this.firstChargeOn,_this.nextChargeOn,_this.accountId,_this.categoryId,_this.active,_this.createdAt);
}

@override
String toString() {
  final _this = this as Subscription;
  return 'Subscription(id: ${_this.id}, userId: ${_this.userId}, name: ${_this.name}, amountCents: ${_this.amountCents}, frequency: ${_this.frequency}, firstChargeOn: ${_this.firstChargeOn}, nextChargeOn: ${_this.nextChargeOn}, accountId: ${_this.accountId}, categoryId: ${_this.categoryId}, active: ${_this.active}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res>  {
  factory $SubscriptionCopyWith(Subscription value, $Res Function(Subscription) _then) = _$SubscriptionCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String name, int amountCents, SubscriptionFrequency frequency, DateTime firstChargeOn, DateTime nextChargeOn, String accountId, String? categoryId, bool active, DateTime? createdAt
});




}
/// @nodoc
class _$SubscriptionCopyWithImpl<$Res>
    implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? amountCents = null,Object? frequency = null,Object? firstChargeOn = null,Object? nextChargeOn = null,Object? accountId = null,Object? categoryId = freezed,Object? active = null,Object? createdAt = freezed,}) {
  return _then(Subscription(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as SubscriptionFrequency,firstChargeOn: null == firstChargeOn ? _self.firstChargeOn : firstChargeOn // ignore: cast_nullable_to_non_nullable
as DateTime,nextChargeOn: null == nextChargeOn ? _self.nextChargeOn : nextChargeOn // ignore: cast_nullable_to_non_nullable
as DateTime,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Subscription].
extension SubscriptionPatterns on Subscription {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subscription value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subscription value)  $default,){
final _that = this;
switch (_that) {
case _Subscription():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subscription value)?  $default,){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String name,  int amountCents,  SubscriptionFrequency frequency,  DateTime firstChargeOn,  DateTime nextChargeOn,  String accountId,  String? categoryId,  bool active,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.amountCents,_that.frequency,_that.firstChargeOn,_that.nextChargeOn,_that.accountId,_that.categoryId,_that.active,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String name,  int amountCents,  SubscriptionFrequency frequency,  DateTime firstChargeOn,  DateTime nextChargeOn,  String accountId,  String? categoryId,  bool active,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Subscription():
return $default(_that.id,_that.userId,_that.name,_that.amountCents,_that.frequency,_that.firstChargeOn,_that.nextChargeOn,_that.accountId,_that.categoryId,_that.active,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String name,  int amountCents,  SubscriptionFrequency frequency,  DateTime firstChargeOn,  DateTime nextChargeOn,  String accountId,  String? categoryId,  bool active,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.userId,_that.name,_that.amountCents,_that.frequency,_that.firstChargeOn,_that.nextChargeOn,_that.accountId,_that.categoryId,_that.active,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subscription implements Subscription {
  const _Subscription({required this.id, required this.userId, required this.name, required this.amountCents, required this.frequency, required this.firstChargeOn, required this.nextChargeOn, required this.accountId, this.categoryId, this.active = true, this.createdAt});
  factory _Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String name;
/// What each charge costs, in cents.
@override final  int amountCents;
@override final  SubscriptionFrequency frequency;
/// The date the schedule is counted from (the "Next charge" date picked
/// in the form). Set by you; never changes by itself.
@override final  DateTime firstChargeOn;
/// When the next expense will be added. The database keeps this right.
@override final  DateTime nextChargeOn;
/// The account that pays for it.
@override final  String accountId;
@override final  String? categoryId;
/// False = paused: nothing is charged until you resume.
@override@JsonKey() final  bool active;
@override final  DateTime? createdAt;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCopyWith<_Subscription> get copyWith => __$SubscriptionCopyWithImpl<_Subscription>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.name, name) || other.name == name)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.frequency, frequency) || other.frequency == frequency)&&(identical(other.firstChargeOn, firstChargeOn) || other.firstChargeOn == firstChargeOn)&&(identical(other.nextChargeOn, nextChargeOn) || other.nextChargeOn == nextChargeOn)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.active, active) || other.active == active)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,name,amountCents,frequency,firstChargeOn,nextChargeOn,accountId,categoryId,active,createdAt);
}

@override
String toString() {
    return 'Subscription(id: $id, userId: $userId, name: $name, amountCents: $amountCents, frequency: $frequency, firstChargeOn: $firstChargeOn, nextChargeOn: $nextChargeOn, accountId: $accountId, categoryId: $categoryId, active: $active, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res> implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(_Subscription value, $Res Function(_Subscription) _then) = __$SubscriptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String name, int amountCents, SubscriptionFrequency frequency, DateTime firstChargeOn, DateTime nextChargeOn, String accountId, String? categoryId, bool active, DateTime? createdAt
});




}
/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? name = null,Object? amountCents = null,Object? frequency = null,Object? firstChargeOn = null,Object? nextChargeOn = null,Object? accountId = null,Object? categoryId = freezed,Object? active = null,Object? createdAt = freezed,}) {
  return _then(_Subscription(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,frequency: null == frequency ? _self.frequency : frequency // ignore: cast_nullable_to_non_nullable
as SubscriptionFrequency,firstChargeOn: null == firstChargeOn ? _self.firstChargeOn : firstChargeOn // ignore: cast_nullable_to_non_nullable
as DateTime,nextChargeOn: null == nextChargeOn ? _self.nextChargeOn : nextChargeOn // ignore: cast_nullable_to_non_nullable
as DateTime,accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

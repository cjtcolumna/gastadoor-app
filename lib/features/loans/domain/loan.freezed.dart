// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'loan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Loan {

 String get id; String get userId;/// Who borrowed the money.
 String get person;/// How much was lent, in cents.
 int get amountCents; DateTime get lentOn;/// When it should be paid back. Null = no due date.
 DateTime? get dueOn; String? get note;/// The account the money left. Null = no account was changed (for a loan
/// made before you started tracking).
 String? get accountId; DateTime? get createdAt;
/// Create a copy of Loan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoanCopyWith<Loan> get copyWith => _$LoanCopyWithImpl<Loan>(this as Loan, _$identity);

  /// Serializes this Loan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Loan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Loan&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.person, _this.person) || other.person == _this.person)&&(identical(other.amountCents, _this.amountCents) || other.amountCents == _this.amountCents)&&(identical(other.lentOn, _this.lentOn) || other.lentOn == _this.lentOn)&&(identical(other.dueOn, _this.dueOn) || other.dueOn == _this.dueOn)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.accountId, _this.accountId) || other.accountId == _this.accountId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Loan;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.person,_this.amountCents,_this.lentOn,_this.dueOn,_this.note,_this.accountId,_this.createdAt);
}

@override
String toString() {
  final _this = this as Loan;
  return 'Loan(id: ${_this.id}, userId: ${_this.userId}, person: ${_this.person}, amountCents: ${_this.amountCents}, lentOn: ${_this.lentOn}, dueOn: ${_this.dueOn}, note: ${_this.note}, accountId: ${_this.accountId}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LoanCopyWith<$Res>  {
  factory $LoanCopyWith(Loan value, $Res Function(Loan) _then) = _$LoanCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String person, int amountCents, DateTime lentOn, DateTime? dueOn, String? note, String? accountId, DateTime? createdAt
});




}
/// @nodoc
class _$LoanCopyWithImpl<$Res>
    implements $LoanCopyWith<$Res> {
  _$LoanCopyWithImpl(this._self, this._then);

  final Loan _self;
  final $Res Function(Loan) _then;

/// Create a copy of Loan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? person = null,Object? amountCents = null,Object? lentOn = null,Object? dueOn = freezed,Object? note = freezed,Object? accountId = freezed,Object? createdAt = freezed,}) {
  return _then(Loan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,person: null == person ? _self.person : person // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,lentOn: null == lentOn ? _self.lentOn : lentOn // ignore: cast_nullable_to_non_nullable
as DateTime,dueOn: freezed == dueOn ? _self.dueOn : dueOn // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Loan].
extension LoanPatterns on Loan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Loan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Loan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Loan value)  $default,){
final _that = this;
switch (_that) {
case _Loan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Loan value)?  $default,){
final _that = this;
switch (_that) {
case _Loan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String person,  int amountCents,  DateTime lentOn,  DateTime? dueOn,  String? note,  String? accountId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Loan() when $default != null:
return $default(_that.id,_that.userId,_that.person,_that.amountCents,_that.lentOn,_that.dueOn,_that.note,_that.accountId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String person,  int amountCents,  DateTime lentOn,  DateTime? dueOn,  String? note,  String? accountId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Loan():
return $default(_that.id,_that.userId,_that.person,_that.amountCents,_that.lentOn,_that.dueOn,_that.note,_that.accountId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String person,  int amountCents,  DateTime lentOn,  DateTime? dueOn,  String? note,  String? accountId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Loan() when $default != null:
return $default(_that.id,_that.userId,_that.person,_that.amountCents,_that.lentOn,_that.dueOn,_that.note,_that.accountId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Loan implements Loan {
  const _Loan({required this.id, required this.userId, required this.person, required this.amountCents, required this.lentOn, this.dueOn, this.note, this.accountId, this.createdAt});
  factory _Loan.fromJson(Map<String, dynamic> json) => _$LoanFromJson(json);

@override final  String id;
@override final  String userId;
/// Who borrowed the money.
@override final  String person;
/// How much was lent, in cents.
@override final  int amountCents;
@override final  DateTime lentOn;
/// When it should be paid back. Null = no due date.
@override final  DateTime? dueOn;
@override final  String? note;
/// The account the money left. Null = no account was changed (for a loan
/// made before you started tracking).
@override final  String? accountId;
@override final  DateTime? createdAt;

/// Create a copy of Loan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoanCopyWith<_Loan> get copyWith => __$LoanCopyWithImpl<_Loan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoanToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Loan&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.person, person) || other.person == person)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.lentOn, lentOn) || other.lentOn == lentOn)&&(identical(other.dueOn, dueOn) || other.dueOn == dueOn)&&(identical(other.note, note) || other.note == note)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,person,amountCents,lentOn,dueOn,note,accountId,createdAt);
}

@override
String toString() {
    return 'Loan(id: $id, userId: $userId, person: $person, amountCents: $amountCents, lentOn: $lentOn, dueOn: $dueOn, note: $note, accountId: $accountId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LoanCopyWith<$Res> implements $LoanCopyWith<$Res> {
  factory _$LoanCopyWith(_Loan value, $Res Function(_Loan) _then) = __$LoanCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String person, int amountCents, DateTime lentOn, DateTime? dueOn, String? note, String? accountId, DateTime? createdAt
});




}
/// @nodoc
class __$LoanCopyWithImpl<$Res>
    implements _$LoanCopyWith<$Res> {
  __$LoanCopyWithImpl(this._self, this._then);

  final _Loan _self;
  final $Res Function(_Loan) _then;

/// Create a copy of Loan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? person = null,Object? amountCents = null,Object? lentOn = null,Object? dueOn = freezed,Object? note = freezed,Object? accountId = freezed,Object? createdAt = freezed,}) {
  return _then(_Loan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,person: null == person ? _self.person : person // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,lentOn: null == lentOn ? _self.lentOn : lentOn // ignore: cast_nullable_to_non_nullable
as DateTime,dueOn: freezed == dueOn ? _self.dueOn : dueOn // ignore: cast_nullable_to_non_nullable
as DateTime?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$LoanPayment {

 String get id; String get userId; String get loanId; int get amountCents; DateTime get paidOn; String? get note;/// The account the money went into. Null = no account was changed.
 String? get accountId; DateTime? get createdAt;
/// Create a copy of LoanPayment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoanPaymentCopyWith<LoanPayment> get copyWith => _$LoanPaymentCopyWithImpl<LoanPayment>(this as LoanPayment, _$identity);

  /// Serializes this LoanPayment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LoanPayment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoanPayment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.loanId, _this.loanId) || other.loanId == _this.loanId)&&(identical(other.amountCents, _this.amountCents) || other.amountCents == _this.amountCents)&&(identical(other.paidOn, _this.paidOn) || other.paidOn == _this.paidOn)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.accountId, _this.accountId) || other.accountId == _this.accountId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LoanPayment;
  return Object.hash(runtimeType,_this.id,_this.userId,_this.loanId,_this.amountCents,_this.paidOn,_this.note,_this.accountId,_this.createdAt);
}

@override
String toString() {
  final _this = this as LoanPayment;
  return 'LoanPayment(id: ${_this.id}, userId: ${_this.userId}, loanId: ${_this.loanId}, amountCents: ${_this.amountCents}, paidOn: ${_this.paidOn}, note: ${_this.note}, accountId: ${_this.accountId}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LoanPaymentCopyWith<$Res>  {
  factory $LoanPaymentCopyWith(LoanPayment value, $Res Function(LoanPayment) _then) = _$LoanPaymentCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String loanId, int amountCents, DateTime paidOn, String? note, String? accountId, DateTime? createdAt
});




}
/// @nodoc
class _$LoanPaymentCopyWithImpl<$Res>
    implements $LoanPaymentCopyWith<$Res> {
  _$LoanPaymentCopyWithImpl(this._self, this._then);

  final LoanPayment _self;
  final $Res Function(LoanPayment) _then;

/// Create a copy of LoanPayment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? loanId = null,Object? amountCents = null,Object? paidOn = null,Object? note = freezed,Object? accountId = freezed,Object? createdAt = freezed,}) {
  return _then(LoanPayment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,loanId: null == loanId ? _self.loanId : loanId // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,paidOn: null == paidOn ? _self.paidOn : paidOn // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LoanPayment].
extension LoanPaymentPatterns on LoanPayment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoanPayment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoanPayment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoanPayment value)  $default,){
final _that = this;
switch (_that) {
case _LoanPayment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoanPayment value)?  $default,){
final _that = this;
switch (_that) {
case _LoanPayment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String loanId,  int amountCents,  DateTime paidOn,  String? note,  String? accountId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoanPayment() when $default != null:
return $default(_that.id,_that.userId,_that.loanId,_that.amountCents,_that.paidOn,_that.note,_that.accountId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String loanId,  int amountCents,  DateTime paidOn,  String? note,  String? accountId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _LoanPayment():
return $default(_that.id,_that.userId,_that.loanId,_that.amountCents,_that.paidOn,_that.note,_that.accountId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String loanId,  int amountCents,  DateTime paidOn,  String? note,  String? accountId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LoanPayment() when $default != null:
return $default(_that.id,_that.userId,_that.loanId,_that.amountCents,_that.paidOn,_that.note,_that.accountId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoanPayment implements LoanPayment {
  const _LoanPayment({required this.id, required this.userId, required this.loanId, required this.amountCents, required this.paidOn, this.note, this.accountId, this.createdAt});
  factory _LoanPayment.fromJson(Map<String, dynamic> json) => _$LoanPaymentFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String loanId;
@override final  int amountCents;
@override final  DateTime paidOn;
@override final  String? note;
/// The account the money went into. Null = no account was changed.
@override final  String? accountId;
@override final  DateTime? createdAt;

/// Create a copy of LoanPayment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoanPaymentCopyWith<_LoanPayment> get copyWith => __$LoanPaymentCopyWithImpl<_LoanPayment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoanPaymentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoanPayment&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.loanId, loanId) || other.loanId == loanId)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.paidOn, paidOn) || other.paidOn == paidOn)&&(identical(other.note, note) || other.note == note)&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,userId,loanId,amountCents,paidOn,note,accountId,createdAt);
}

@override
String toString() {
    return 'LoanPayment(id: $id, userId: $userId, loanId: $loanId, amountCents: $amountCents, paidOn: $paidOn, note: $note, accountId: $accountId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LoanPaymentCopyWith<$Res> implements $LoanPaymentCopyWith<$Res> {
  factory _$LoanPaymentCopyWith(_LoanPayment value, $Res Function(_LoanPayment) _then) = __$LoanPaymentCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String loanId, int amountCents, DateTime paidOn, String? note, String? accountId, DateTime? createdAt
});




}
/// @nodoc
class __$LoanPaymentCopyWithImpl<$Res>
    implements _$LoanPaymentCopyWith<$Res> {
  __$LoanPaymentCopyWithImpl(this._self, this._then);

  final _LoanPayment _self;
  final $Res Function(_LoanPayment) _then;

/// Create a copy of LoanPayment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? loanId = null,Object? amountCents = null,Object? paidOn = null,Object? note = freezed,Object? accountId = freezed,Object? createdAt = freezed,}) {
  return _then(_LoanPayment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,loanId: null == loanId ? _self.loanId : loanId // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,paidOn: null == paidOn ? _self.paidOn : paidOn // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,accountId: freezed == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on

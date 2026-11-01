// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Loan _$LoanFromJson(Map<String, dynamic> json) => _Loan(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  person: json['person'] as String,
  amountCents: (json['amount_cents'] as num).toInt(),
  lentOn: DateTime.parse(json['lent_on'] as String),
  dueOn: json['due_on'] == null
      ? null
      : DateTime.parse(json['due_on'] as String),
  note: json['note'] as String?,
  accountId: json['account_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LoanToJson(_Loan instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'person': instance.person,
  'amount_cents': instance.amountCents,
  'lent_on': instance.lentOn.toIso8601String(),
  'due_on': instance.dueOn?.toIso8601String(),
  'note': instance.note,
  'account_id': instance.accountId,
  'created_at': instance.createdAt?.toIso8601String(),
};

_LoanPayment _$LoanPaymentFromJson(Map<String, dynamic> json) => _LoanPayment(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  loanId: json['loan_id'] as String,
  amountCents: (json['amount_cents'] as num).toInt(),
  paidOn: DateTime.parse(json['paid_on'] as String),
  note: json['note'] as String?,
  accountId: json['account_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LoanPaymentToJson(_LoanPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'loan_id': instance.loanId,
      'amount_cents': instance.amountCents,
      'paid_on': instance.paidOn.toIso8601String(),
      'note': instance.note,
      'account_id': instance.accountId,
      'created_at': instance.createdAt?.toIso8601String(),
    };

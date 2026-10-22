// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Transaction _$TransactionFromJson(Map<String, dynamic> json) => _Transaction(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  accountId: json['account_id'] as String,
  toAccountId: json['to_account_id'] as String?,
  categoryId: json['category_id'] as String?,
  kind: $enumDecode(_$TransactionKindEnumMap, json['kind']),
  amountCents: (json['amount_cents'] as num).toInt(),
  occurredOn: DateTime.parse(json['occurred_on'] as String),
  note: json['note'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$TransactionToJson(_Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'account_id': instance.accountId,
      'to_account_id': instance.toAccountId,
      'category_id': instance.categoryId,
      'kind': _$TransactionKindEnumMap[instance.kind]!,
      'amount_cents': instance.amountCents,
      'occurred_on': instance.occurredOn.toIso8601String(),
      'note': instance.note,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$TransactionKindEnumMap = {
  TransactionKind.expense: 'expense',
  TransactionKind.income: 'income',
  TransactionKind.transfer: 'transfer',
};

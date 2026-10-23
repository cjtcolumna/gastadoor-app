// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Account _$AccountFromJson(Map<String, dynamic> json) => _Account(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$AccountTypeEnumMap, json['type']),
  currency: json['currency'] as String? ?? 'PHP',
  openingBalanceCents: (json['opening_balance_cents'] as num?)?.toInt() ?? 0,
  archived: json['archived'] as bool? ?? false,
  parentId: json['parent_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AccountToJson(_Account instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'name': instance.name,
  'type': _$AccountTypeEnumMap[instance.type]!,
  'currency': instance.currency,
  'opening_balance_cents': instance.openingBalanceCents,
  'archived': instance.archived,
  'parent_id': instance.parentId,
  'created_at': instance.createdAt?.toIso8601String(),
};

const _$AccountTypeEnumMap = {
  AccountType.cash: 'cash',
  AccountType.bank: 'bank',
  AccountType.creditCard: 'credit_card',
  AccountType.eWallet: 'e_wallet',
  AccountType.other: 'other',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Budget _$BudgetFromJson(Map<String, dynamic> json) => _Budget(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  categoryId: json['category_id'] as String?,
  name: json['name'] as String,
  period:
      $enumDecodeNullable(_$BudgetPeriodEnumMap, json['period']) ??
      BudgetPeriod.monthly,
  amountCents: (json['amount_cents'] as num).toInt(),
  startsOn: DateTime.parse(json['starts_on'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$BudgetToJson(_Budget instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'category_id': instance.categoryId,
  'name': instance.name,
  'period': _$BudgetPeriodEnumMap[instance.period]!,
  'amount_cents': instance.amountCents,
  'starts_on': instance.startsOn.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
};

const _$BudgetPeriodEnumMap = {
  BudgetPeriod.weekly: 'weekly',
  BudgetPeriod.monthly: 'monthly',
  BudgetPeriod.yearly: 'yearly',
};

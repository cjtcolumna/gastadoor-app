// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      amountCents: (json['amount_cents'] as num).toInt(),
      frequency: $enumDecode(_$SubscriptionFrequencyEnumMap, json['frequency']),
      firstChargeOn: DateTime.parse(json['first_charge_on'] as String),
      nextChargeOn: DateTime.parse(json['next_charge_on'] as String),
      accountId: json['account_id'] as String,
      categoryId: json['category_id'] as String?,
      active: json['active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'amount_cents': instance.amountCents,
      'frequency': _$SubscriptionFrequencyEnumMap[instance.frequency]!,
      'first_charge_on': instance.firstChargeOn.toIso8601String(),
      'next_charge_on': instance.nextChargeOn.toIso8601String(),
      'account_id': instance.accountId,
      'category_id': instance.categoryId,
      'active': instance.active,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$SubscriptionFrequencyEnumMap = {
  SubscriptionFrequency.monthly: 'monthly',
  SubscriptionFrequency.yearly: 'yearly',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  name: json['name'] as String,
  kind: $enumDecode(_$TransactionKindEnumMap, json['kind']),
  icon: json['icon'] as String?,
  color: json['color'] as String?,
  parentId: json['parent_id'] as String?,
  archived: json['archived'] as bool? ?? false,
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'name': instance.name,
  'kind': _$TransactionKindEnumMap[instance.kind]!,
  'icon': instance.icon,
  'color': instance.color,
  'parent_id': instance.parentId,
  'archived': instance.archived,
};

const _$TransactionKindEnumMap = {
  TransactionKind.expense: 'expense',
  TransactionKind.income: 'income',
  TransactionKind.transfer: 'transfer',
};

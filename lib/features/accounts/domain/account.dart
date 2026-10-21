import 'package:freezed_annotation/freezed_annotation.dart';

part 'account.freezed.dart';
part 'account.g.dart';

enum AccountType {
  cash,
  bank,
  @JsonValue('credit_card')
  creditCard,
  @JsonValue('e_wallet')
  eWallet,
  other,
}

@freezed
abstract class Account with _$Account {
  const factory Account({
    required String id,
    required String userId,
    required String name,
    required AccountType type,
    @Default('PHP') String currency,
    @Default(0) int openingBalanceCents,
    @Default(false) bool archived,
    DateTime? createdAt,
  }) = _Account;

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);
}

extension AccountTypeDb on AccountType {
  /// The text saved in the database, e.g. AccountType.eWallet -> 'e_wallet'.
  String get dbValue => _$AccountTypeEnumMap[this]!;
}

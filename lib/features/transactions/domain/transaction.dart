import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

enum TransactionKind { expense, income }

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String userId,
    required String accountId,
    String? categoryId,
    required TransactionKind kind,

    /// Always positive. [kind] decides whether money goes in or out.
    required int amountCents,
    required DateTime occurredOn,
    String? note,
    DateTime? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
}

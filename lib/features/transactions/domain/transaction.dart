import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';
part 'transaction.g.dart';

/// expense: money out. income: money in.
/// transfer: money moved between two of your own accounts (not spending).
enum TransactionKind { expense, income, transfer }

@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String userId,

    /// The account the money comes from (or goes into, for income).
    required String accountId,

    /// Transfers only: the account the money moves to.
    String? toAccountId,
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

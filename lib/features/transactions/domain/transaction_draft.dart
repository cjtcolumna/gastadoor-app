import '../../../core/utils/dates.dart';
import 'transaction.dart';

/// What the add/edit form collects before it is saved.
/// It has no id yet: the database gives it one when it's inserted.
class TransactionDraft {
  const TransactionDraft({
    required this.kind,
    required this.amountCents,
    required this.accountId,
    required this.occurredOn,
    this.toAccountId,
    this.categoryId,
    this.note,
  });

  /// Pre-fills the form when editing an existing transaction.
  factory TransactionDraft.fromTransaction(Transaction t) => TransactionDraft(
    kind: t.kind,
    amountCents: t.amountCents,
    accountId: t.accountId,
    toAccountId: t.toAccountId,
    occurredOn: t.occurredOn,
    categoryId: t.categoryId,
    note: t.note,
  );

  final TransactionKind kind;

  /// Always positive. [kind] decides whether money goes in or out.
  final int amountCents;

  /// For a transfer, the account the money leaves ("From").
  final String accountId;

  /// Transfers only: the account the money arrives in ("To").
  final String? toAccountId;
  final String? categoryId;
  final DateTime occurredOn;
  final String? note;

  bool get isTransfer => kind == TransactionKind.transfer;

  /// The columns to send to Supabase. `user_id` is filled in by the database.
  /// Transfers never have a category; expenses and income never have a
  /// "To" account (the database checks this too).
  Map<String, dynamic> toRow() {
    final trimmedNote = note?.trim() ?? '';
    return {
      'kind': kind.name,
      'amount_cents': amountCents,
      'account_id': accountId,
      'to_account_id': isTransfer ? toAccountId : null,
      'category_id': isTransfer ? null : categoryId,
      'occurred_on': toDbDate(occurredOn),
      'note': trimmedNote.isEmpty ? null : trimmedNote,
    };
  }
}

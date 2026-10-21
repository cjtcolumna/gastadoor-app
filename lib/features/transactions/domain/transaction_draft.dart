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
    this.categoryId,
    this.note,
  });

  /// Pre-fills the form when editing an existing transaction.
  factory TransactionDraft.fromTransaction(Transaction t) => TransactionDraft(
    kind: t.kind,
    amountCents: t.amountCents,
    accountId: t.accountId,
    occurredOn: t.occurredOn,
    categoryId: t.categoryId,
    note: t.note,
  );

  final TransactionKind kind;

  /// Always positive. [kind] decides whether money goes in or out.
  final int amountCents;
  final String accountId;
  final String? categoryId;
  final DateTime occurredOn;
  final String? note;

  /// The columns to send to Supabase. `user_id` is filled in by the database.
  Map<String, dynamic> toRow() {
    final trimmedNote = note?.trim() ?? '';
    return {
      'kind': kind.name,
      'amount_cents': amountCents,
      'account_id': accountId,
      'category_id': categoryId,
      'occurred_on': toDbDate(occurredOn),
      'note': trimmedNote.isEmpty ? null : trimmedNote,
    };
  }
}

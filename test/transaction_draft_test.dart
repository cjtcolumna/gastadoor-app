import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';

void main() {
  test('toRow sends cents, a plain date, and the kind as text', () {
    final row = TransactionDraft(
      kind: TransactionKind.expense,
      amountCents: 18950,
      accountId: 'acc-1',
      categoryId: 'cat-1',
      occurredOn: DateTime(2026, 10, 22, 14, 5),
      note: '  Jollibee  ',
    ).toRow();

    expect(row, {
      'kind': 'expense',
      'amount_cents': 18950,
      'account_id': 'acc-1',
      'category_id': 'cat-1',
      'occurred_on': '2026-10-22',
      'note': 'Jollibee',
    });
  });

  test('an empty note and no category are saved as null', () {
    final row = TransactionDraft(
      kind: TransactionKind.income,
      amountCents: 100,
      accountId: 'acc-1',
      occurredOn: DateTime(2026, 1, 1),
      note: '   ',
    ).toRow();

    expect(row['note'], isNull);
    expect(row['category_id'], isNull);
    expect(row['kind'], 'income');
  });
}

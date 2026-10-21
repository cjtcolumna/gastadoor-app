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
      'to_account_id': null,
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

  test('a transfer sends its To account and never a category', () {
    final row = TransactionDraft(
      kind: TransactionKind.transfer,
      amountCents: 100000,
      accountId: 'cash',
      toAccountId: 'gcash',
      categoryId: 'food', // left over from switching tabs; must be dropped
      occurredOn: DateTime(2026, 10, 22),
    ).toRow();

    expect(row['kind'], 'transfer');
    expect(row['account_id'], 'cash');
    expect(row['to_account_id'], 'gcash');
    expect(row['category_id'], isNull);
  });

  test('expenses never send a To account', () {
    final row = TransactionDraft(
      kind: TransactionKind.expense,
      amountCents: 100,
      accountId: 'cash',
      toAccountId: 'gcash', // left over from the Transfer tab
      occurredOn: DateTime(2026, 10, 22),
    ).toRow();

    expect(row['to_account_id'], isNull);
  });
}

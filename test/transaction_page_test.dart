import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/transactions/domain/transaction_page.dart';

/// A page with [count] fake items (the items' contents don't matter here).
TransactionPage pageOf(int page, int count, int total) {
  final item = TransactionListItem.fromRow({
    'id': 't',
    'user_id': 'u',
    'account_id': 'a',
    'kind': 'expense',
    'amount_cents': 100,
    'occurred_on': '2026-10-01',
    'account': {'name': 'Cash'},
    'categories': null,
  });
  return TransactionPage(
    items: List.filled(count, item),
    page: page,
    totalCount: total,
  );
}

void main() {
  test('asks the database for 20 rows per page', () {
    expect(TransactionPage.rowRange(0), (0, 19));
    expect(TransactionPage.rowRange(1), (20, 39));
    expect(TransactionPage.rowRange(2, pageSize: 10), (20, 29));
  });

  test('works out the number of pages', () {
    expect(pageOf(0, 0, 0).pageCount, 1);
    expect(pageOf(0, 20, 20).pageCount, 1);
    expect(pageOf(0, 20, 21).pageCount, 2);
    expect(pageOf(0, 20, 45).pageCount, 3);
  });

  test('knows when there is a previous or next page', () {
    final first = pageOf(0, 20, 45);
    expect(first.hasPrevious, isFalse);
    expect(first.hasNext, isTrue);

    final last = pageOf(2, 5, 45);
    expect(last.hasPrevious, isTrue);
    expect(last.hasNext, isFalse);
  });

  test('shows which rows are on screen', () {
    expect(pageOf(0, 20, 45).shownRange, (1, 20));
    expect(pageOf(2, 5, 45).shownRange, (41, 45));
    expect(pageOf(0, 0, 0).shownRange, (0, 0));
  });

  test('reads account and category names from a joined row', () {
    final item = pageOf(0, 1, 1).items.single;
    expect(item.accountName, 'Cash');
    expect(item.categoryName, isNull);
    expect(item.transaction.amountCents, 100);
  });

  test('History names pockets "GoTyme › Travel"', () {
    TransactionListItem item(String from, String? to) =>
        TransactionListItem.fromRow({
          'id': 'x',
          'user_id': 'u',
          'account_id': from,
          'to_account_id': to,
          'kind': to == null ? 'expense' : 'transfer',
          'amount_cents': 100,
          'occurred_on': '2026-10-24',
          'account': {'name': 'db name'},
          'to_account': to == null ? null : {'name': 'db to name'},
          'categories': null,
        });
    const all = [
      Account(id: 'g', userId: 'u', name: 'GoTyme', type: AccountType.bank),
      Account(
        id: 't',
        userId: 'u',
        name: 'Travel',
        type: AccountType.bank,
        parentId: 'g',
      ),
    ];

    final labelled = labelAccounts([
      item('t', null),
      item('g', 't'),
      item('unknown', null),
    ], all);

    expect(labelled[0].accountName, 'GoTyme › Travel');
    expect(labelled[1].accountName, 'GoTyme');
    expect(labelled[1].toAccountName, 'GoTyme › Travel');
    // Not in the list: keeps the name from the database.
    expect(labelled[2].accountName, 'db name');
  });
}

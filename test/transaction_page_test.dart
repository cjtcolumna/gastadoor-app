import 'package:flutter_test/flutter_test.dart';
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
}

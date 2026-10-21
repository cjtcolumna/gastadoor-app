import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/transactions/domain/month_totals.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_page.dart';

Transaction txn(String id, TransactionKind kind, int cents, DateTime on) =>
    Transaction(
      id: id,
      userId: 'u',
      accountId: 'a',
      kind: kind,
      amountCents: cents,
      occurredOn: on,
    );

TransactionListItem item(Transaction t) =>
    TransactionListItem(transaction: t, accountName: 'Cash');

void main() {
  const expense = TransactionKind.expense;
  const income = TransactionKind.income;

  test('MonthTotals adds income and expenses separately', () {
    final totals = MonthTotals.from([
      txn('1', expense, 18900, DateTime(2026, 10, 1)),
      txn('2', income, 2500000, DateTime(2026, 10, 15)),
      txn('3', expense, 24500, DateTime(2026, 10, 20)),
    ]);
    expect(totals.incomeCents, 2500000);
    expect(totals.expenseCents, 43400);
  });

  test('MonthTotals of nothing is zero', () {
    final totals = MonthTotals.from([]);
    expect(totals.incomeCents, 0);
    expect(totals.expenseCents, 0);
  });

  test('groupByDay keeps order and puts same-day items together', () {
    final groups = groupByDay([
      item(txn('a', expense, 100, DateTime(2026, 10, 22))),
      item(txn('b', expense, 200, DateTime(2026, 10, 22))),
      item(txn('c', income, 300, DateTime(2026, 10, 20))),
    ]);

    expect(groups.length, 2);
    expect(groups[0].$1, DateTime(2026, 10, 22));
    expect(groups[0].$2.map((i) => i.transaction.id), ['a', 'b']);
    expect(groups[1].$1, DateTime(2026, 10, 20));
    expect(groups[1].$2.single.transaction.id, 'c');
  });

  test('groupByDay of an empty list is empty', () {
    expect(groupByDay([]), isEmpty);
  });
}

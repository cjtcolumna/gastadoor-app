import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/utils/money.dart';
import 'package:gastadoor/features/transactions/domain/spending_breakdown.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

Transaction txn(TransactionKind kind, int cents, {String? cat, DateTime? on}) =>
    Transaction(
      id: '$kind$cents$cat',
      userId: 'u',
      accountId: 'a',
      categoryId: cat,
      kind: kind,
      amountCents: cents,
      occurredOn: on ?? DateTime(2026, 10, 5),
    );

void main() {
  const expense = TransactionKind.expense;

  test('adds expenses per category, biggest first', () {
    final slices = spendingByCategory([
      txn(expense, 1000, cat: 'food'),
      txn(expense, 5000, cat: 'bills'),
      txn(expense, 2500, cat: 'food'),
      txn(expense, 700), // no category
      txn(TransactionKind.income, 99999, cat: 'salary'),
      txn(TransactionKind.transfer, 88888),
    ]);
    expect(slices.map((s) => (s.categoryId, s.cents)), [
      ('bills', 5000),
      ('food', 3500),
      (null, 700),
    ]);
  });

  test('folds everything after the top 5 into Other', () {
    final slices = [
      for (var i = 8; i >= 1; i--)
        CategorySlice(categoryId: 'c$i', cents: i * 100),
    ];
    final top = topWithOther(slices);
    expect(top.length, 6);
    expect(top.last.isOther, isTrue);
    expect(top.last.cents, 300 + 200 + 100);
    expect(top.first.categoryId, 'c8');
  });

  test('a single leftover slice is not hidden in Other', () {
    final slices = [
      for (var i = 6; i >= 1; i--)
        CategorySlice(categoryId: 'c$i', cents: i * 100),
    ];
    expect(topWithOther(slices).any((s) => s.isOther), isFalse);
  });

  test('6-month trend fills every month, oldest first', () {
    final trend = monthlyTrend([
      txn(expense, 1000, on: DateTime(2026, 10, 3)),
      txn(TransactionKind.income, 50000, on: DateTime(2026, 10, 15)),
      txn(expense, 2000, on: DateTime(2026, 8, 20)),
      txn(expense, 9999, on: DateTime(2026, 4, 1)), // outside the 6 months
    ], lastMonth: DateTime(2026, 10));

    expect(trend.map((p) => p.month.month), [5, 6, 7, 8, 9, 10]);
    expect(trend.last.totals.expenseCents, 1000);
    expect(trend.last.totals.incomeCents, 50000);
    expect(trend[3].totals.expenseCents, 2000); // August
    expect(trend[0].totals.expenseCents, 0); // May: nothing
  });

  test('the trend crosses into the previous year', () {
    final trend = monthlyTrend([], lastMonth: DateTime(2027, 2));
    expect(trend.first.month, DateTime(2026, 9));
    expect(trend.last.month, DateTime(2027, 2));
  });

  test('compact amounts for chart labels', () {
    expect(Money.formatCompact(2500000), '₱25K');
    expect(Money.formatCompact(0), '₱0');
  });
}

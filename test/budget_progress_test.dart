import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/budgets/data/budgets_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget.dart';
import 'package:gastadoor/features/budgets/domain/budget_progress.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

Budget budget({String? categoryId, int limit = 500000}) => Budget(
  id: 'b',
  userId: 'u',
  categoryId: categoryId,
  name: 'Test',
  amountCents: limit,
  startsOn: DateTime(2026, 10, 1),
);

Transaction txn(TransactionKind kind, int cents, {String? categoryId}) =>
    Transaction(
      id: 't$cents',
      userId: 'u',
      accountId: 'a',
      categoryId: categoryId,
      kind: kind,
      amountCents: cents,
      occurredOn: DateTime(2026, 10, 5),
    );

void main() {
  const expense = TransactionKind.expense;

  group('what counts toward a budget', () {
    final month = [
      txn(expense, 18900, categoryId: 'food'),
      txn(expense, 24500, categoryId: 'transport'),
      txn(expense, 5000), // no category
      txn(TransactionKind.income, 2500000, categoryId: 'salary'),
      txn(TransactionKind.transfer, 100000),
    ];

    test('a category budget counts only that category', () {
      final p = BudgetProgress.compute(budget(categoryId: 'food'), month);
      expect(p.spentCents, 18900);
    });

    test('an all-spending budget counts every expense', () {
      final p = BudgetProgress.compute(budget(), month);
      expect(p.spentCents, 18900 + 24500 + 5000);
    });

    test('income and transfers never count', () {
      final p = BudgetProgress.compute(budget(), [
        txn(TransactionKind.income, 100),
        txn(TransactionKind.transfer, 100),
      ]);
      expect(p.spentCents, 0);
    });
  });

  group('status and amounts', () {
    BudgetProgress spent(int cents) =>
        BudgetProgress(budget: budget(limit: 10000), spentCents: cents);

    test('under 75% is ok', () {
      expect(spent(0).status, BudgetStatus.ok);
      expect(spent(7499).status, BudgetStatus.ok);
    });

    test('75% up to 100% is a warning', () {
      expect(spent(7500).status, BudgetStatus.warning);
      expect(spent(10000).status, BudgetStatus.warning);
    });

    test('over 100% is over', () {
      expect(spent(10001).status, BudgetStatus.over);
    });

    test('left and over amounts', () {
      expect(spent(3760).leftCents, 6240);
      expect(spent(3760).overCents, 0);
      expect(spent(10320).leftCents, 0);
      expect(spent(10320).overCents, 320);
    });

    test('the bar stops at full when over', () {
      expect(spent(5000).barFraction, 0.5);
      expect(spent(25000).barFraction, 1.0);
    });
  });

  test('sorting: All spending first, then most used', () {
    BudgetProgress p(String? cat, int limit, int spent) => BudgetProgress(
      budget: budget(categoryId: cat, limit: limit),
      spentCents: spent,
    );
    final sorted = sortProgress([
      p('food', 10000, 2000), // 20%
      p('fun', 10000, 9000), // 90%
      p(null, 50000, 1000), // all spending, 2%
      p('bills', 1000, 500), // 50%
    ]);
    expect(sorted.map((x) => x.budget.categoryId), [
      null,
      'fun',
      'bills',
      'food',
    ]);
  });
}

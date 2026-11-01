import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/budgets/data/budgets_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_progress.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

Category category(
  String id, {
  int? limit,
  TransactionKind kind = TransactionKind.expense,
}) => Category(id: id, userId: 'u', name: id, kind: kind, budgetCents: limit);

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

  group('which categories get a budget, and what counts toward it', () {
    final month = [
      txn(expense, 18900, categoryId: 'food'),
      txn(expense, 1100, categoryId: 'food'),
      txn(expense, 24500, categoryId: 'transport'),
      txn(expense, 5000), // no category
      txn(TransactionKind.income, 2500000, categoryId: 'salary'),
      txn(TransactionKind.transfer, 100000),
    ];

    test('only categories with a limit get a budget', () {
      final items = BudgetProgress.forCategories([
        category('food', limit: 500000),
        category('transport'), // no limit
      ], month);
      expect(items.map((p) => p.category.id), ['food']);
    });

    test('a budget counts only its own category, adding every expense', () {
      final items = BudgetProgress.forCategories([
        category('food', limit: 500000),
        category('transport', limit: 300000),
      ], month);
      expect(items[0].spentCents, 18900 + 1100);
      expect(items[1].spentCents, 24500);
      expect(items[0].limitCents, 500000);
    });

    test('a category with no spending is at zero', () {
      final items = BudgetProgress.forCategories([
        category('fun', limit: 100000),
      ], month);
      expect(items.single.spentCents, 0);
    });

    test('income and transfers never count', () {
      final items = BudgetProgress.forCategories(
        [category('salary', limit: 100000)],
        [
          txn(TransactionKind.income, 100, categoryId: 'salary'),
          txn(TransactionKind.transfer, 100, categoryId: 'salary'),
        ],
      );
      expect(items.single.spentCents, 0);
    });

    test('an income category never gets a budget, even with a stray limit', () {
      final items = BudgetProgress.forCategories([
        category('salary', limit: 100000, kind: TransactionKind.income),
      ], month);
      expect(items, isEmpty);
    });
  });

  group('status and amounts', () {
    BudgetUsage spent(int cents) =>
        BudgetUsage(limitCents: 10000, spentCents: cents);

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

    test('percent used is a whole number that rounds down', () {
      expect(spent(0).percentUsed, 0);
      expect(spent(4760).percentUsed, 47);
      expect(spent(7499).percentUsed, 74); // not 75 yet: still green
      expect(spent(7500).percentUsed, 75); // amber starts here
      expect(spent(10000).percentUsed, 100);
      expect(spent(11800).percentUsed, 118); // it can go past 100
    });

    test('percent used is 0 when there is no limit', () {
      expect(const BudgetUsage(limitCents: 0, spentCents: 500).percentUsed, 0);
    });
  });

  group('the total over all limits', () {
    BudgetProgress p(String id, int limit, int spent) => BudgetProgress(
      category: category(id, limit: limit),
      limitCents: limit,
      spentCents: spent,
    );

    test('adds up the limits and what was spent against them', () {
      final items = [p('food', 500000, 200000), p('fun', 100000, 150000)];
      final summary = BudgetSummary.compute(items, const []);
      expect(summary.limitCents, 600000);
      expect(summary.spentCents, 350000);
      expect(summary.leftCents, 250000);
      expect(summary.hasLimits, isTrue);
    });

    test('spending outside the limits is worked out separately', () {
      final items = [p('food', 500000, 20000)];
      final month = [
        txn(expense, 20000, categoryId: 'food'),
        txn(expense, 7000, categoryId: 'fun'), // no limit
        txn(expense, 3000), // no category
        txn(TransactionKind.income, 999999, categoryId: 'salary'),
      ];
      final summary = BudgetSummary.compute(items, month);
      expect(summary.spentCents, 20000);
      expect(summary.outsideCents, 10000);
    });

    test('one category over does not make the total over', () {
      // Fun is over its limit, but together there is still room.
      final items = [p('food', 500000, 0), p('fun', 100000, 150000)];
      final summary = BudgetSummary.compute(items, const []);
      expect(summary.status, BudgetStatus.ok);
      expect(items[1].status, BudgetStatus.over);
    });

    test('the total goes red only when all the limits together are passed', () {
      final items = [p('food', 100000, 90000), p('fun', 100000, 130000)];
      final summary = BudgetSummary.compute(items, const []);
      expect(summary.status, BudgetStatus.over);
      expect(summary.overCents, 20000);
    });

    test('no limits at all', () {
      final summary = BudgetSummary.compute(const [], [
        txn(expense, 5000, categoryId: 'food'),
      ]);
      expect(summary.hasLimits, isFalse);
      expect(summary.limitCents, 0);
      expect(summary.barFraction, 0);
      expect(summary.outsideCents, 5000);
    });
  });

  group('sorting', () {
    BudgetProgress p(String id, int limit, int spent) => BudgetProgress(
      category: category(id, limit: limit),
      limitCents: limit,
      spentCents: spent,
    );

    test('the most used comes first', () {
      final sorted = sortProgress([
        p('food', 10000, 2000), // 20%
        p('fun', 10000, 9000), // 90%
        p('bills', 1000, 500), // 50%
      ]);
      expect(sorted.map((x) => x.category.id), ['fun', 'bills', 'food']);
    });

    test('budgets used the same amount go by name', () {
      final sorted = sortProgress([
        p('zoo', 10000, 5000),
        p('art', 20000, 10000),
        p('mid', 1000, 500),
      ]);
      expect(sorted.map((x) => x.category.id), ['art', 'mid', 'zoo']);
    });
  });
}

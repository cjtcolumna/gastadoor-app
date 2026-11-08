import '../../categories/domain/category.dart';
import '../../transactions/domain/transaction.dart';

/// How a budget is doing: fine, getting close, or over the limit.
enum BudgetStatus {
  /// Under 75% used.
  ok,

  /// 75% to 100% used.
  warning,

  /// More than 100% used.
  over,
}

/// A limit and how much of it is spent. The math (left, over, the bar, the
/// status) lives here once, and is shared by one category's budget and by the
/// total over all of them.
class BudgetUsage {
  const BudgetUsage({required this.limitCents, required this.spentCents});

  final int limitCents;
  final int spentCents;

  /// Money left to spend (0 once you're over).
  int get leftCents => spentCents >= limitCents ? 0 : limitCents - spentCents;

  /// How far over the limit you are (0 if you're not over).
  int get overCents => spentCents > limitCents ? spentCents - limitCents : 0;

  /// 0.0 to 1.0 for a progress bar or ring (stays at 1.0 once you're over).
  double get barFraction =>
      limitCents == 0 ? 0 : (spentCents / limitCents).clamp(0.0, 1.0);

  /// How much of the limit is used, as a whole number (it can pass 100).
  /// It rounds down, so "75%" only shows once you really are at 75%, which
  /// is where [status] turns amber.
  int get percentUsed => limitCents == 0 ? 0 : spentCents * 100 ~/ limitCents;

  /// Uses whole-number math (no decimals) so 75% is exact:
  /// spent / limit >= 3/4  is the same as  spent * 4 >= limit * 3.
  BudgetStatus get status {
    if (spentCents > limitCents) return BudgetStatus.over;
    if (spentCents * 4 >= limitCents * 3) return BudgetStatus.warning;
    return BudgetStatus.ok;
  }
}

/// One category's limit plus how much has been spent in it this period.
class BudgetProgress extends BudgetUsage {
  const BudgetProgress({
    required this.category,
    required super.limitCents,
    required super.spentCents,
  });

  /// One [BudgetProgress] for each expense category that has a limit.
  /// Adds up this period's expenses per category; income and transfers
  /// never count, and neither do expenses with no category.
  static List<BudgetProgress> forCategories(
    List<Category> categories,
    List<Transaction> month,
  ) {
    final spentBy = <String, int>{};
    for (final t in month) {
      final id = t.categoryId;
      if (t.kind != TransactionKind.expense || id == null) continue;
      spentBy[id] = (spentBy[id] ?? 0) + t.amountCents;
    }
    return [
      for (final c in categories)
        if (c.kind == TransactionKind.expense && c.budgetCents != null)
          BudgetProgress(
            category: c,
            limitCents: c.budgetCents!,
            spentCents: spentBy[c.id] ?? 0,
          ),
    ];
  }

  final Category category;
}

/// All the limits added together, against what was spent in those same
/// categories. This is what the ring on the Budget page shows.
class BudgetSummary extends BudgetUsage {
  const BudgetSummary({
    required super.limitCents,
    required super.spentCents,
    required this.outsideCents,
  });

  /// Adds up [items]. [month] is every transaction in the period, so the
  /// spending that is not in any limited category can be worked out too.
  factory BudgetSummary.compute(
    List<BudgetProgress> items,
    List<Transaction> month,
  ) {
    var limit = 0;
    var spent = 0;
    for (final p in items) {
      limit += p.limitCents;
      spent += p.spentCents;
    }
    var allExpenses = 0;
    for (final t in month) {
      if (t.kind == TransactionKind.expense) allExpenses += t.amountCents;
    }
    return BudgetSummary(
      limitCents: limit,
      spentCents: spent,
      outsideCents: allExpenses - spent,
    );
  }

  /// Spent in categories that have no limit (or none at all). It is not part
  /// of the ring, but worth a quiet line so it is not forgotten.
  final int outsideCents;

  /// False until at least one category has a limit.
  bool get hasLimits => limitCents > 0;
}

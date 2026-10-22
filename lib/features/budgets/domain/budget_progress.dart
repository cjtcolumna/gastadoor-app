import '../../transactions/domain/transaction.dart';
import 'budget.dart';

/// How a budget is doing: fine, getting close, or over the limit.
enum BudgetStatus {
  /// Under 75% used.
  ok,

  /// 75% to 100% used.
  warning,

  /// More than 100% used.
  over,
}

/// A budget plus how much has been spent against it this month.
class BudgetProgress {
  const BudgetProgress({required this.budget, required this.spentCents});

  /// Adds up this month's expenses that count toward [budget]:
  /// every expense for an "all spending" budget, or only expenses in the
  /// budget's category. Income and transfers never count.
  factory BudgetProgress.compute(Budget budget, List<Transaction> month) {
    var spent = 0;
    for (final t in month) {
      if (t.kind != TransactionKind.expense) continue;
      if (budget.categoryId != null && t.categoryId != budget.categoryId) {
        continue;
      }
      spent += t.amountCents;
    }
    return BudgetProgress(budget: budget, spentCents: spent);
  }

  final Budget budget;
  final int spentCents;

  int get limitCents => budget.amountCents;

  /// Money left to spend (0 once you're over).
  int get leftCents => spentCents >= limitCents ? 0 : limitCents - spentCents;

  /// How far over the limit you are (0 if you're not over).
  int get overCents => spentCents > limitCents ? spentCents - limitCents : 0;

  /// 0.0 to 1.0 for the progress bar (stays at 1.0 once you're over).
  double get barFraction =>
      limitCents == 0 ? 0 : (spentCents / limitCents).clamp(0.0, 1.0);

  /// Uses whole-number math (no decimals) so 75% is exact:
  /// spent / limit >= 3/4  is the same as  spent * 4 >= limit * 3.
  BudgetStatus get status {
    if (spentCents > limitCents) return BudgetStatus.over;
    if (spentCents * 4 >= limitCents * 3) return BudgetStatus.warning;
    return BudgetStatus.ok;
  }
}

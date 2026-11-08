import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/data/categories_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/budget_progress.dart';

/// Each expense category that has a monthly limit, with how much has been
/// spent against it in the current budget period. The most used come first.
/// Updates on its own when categories or this period's transactions change.
///
/// The limit is a property of the category (`categories.budget_cents`), so
/// there is no separate list of budgets to load.
final budgetProgressProvider = FutureProvider<List<BudgetProgress>>((
  ref,
) async {
  final categories = await ref.watch(categoriesProvider.future);
  final month = await ref.watch(monthTransactionsProvider.future);
  return sortProgress(BudgetProgress.forCategories(categories, month));
});

/// All the limits together against what was spent in those categories: the
/// numbers behind the ring on the Budget page.
final budgetSummaryProvider = FutureProvider<BudgetSummary>((ref) async {
  final items = await ref.watch(budgetProgressProvider.future);
  final month = await ref.watch(monthTransactionsProvider.future);
  return BudgetSummary.compute(items, month);
});

/// The most-used budgets first; budgets used the same amount go by name.
/// (Dart's `sort` doesn't promise to keep equal items in order, so the name
/// is the tie-break that makes the order always the same.)
List<BudgetProgress> sortProgress(List<BudgetProgress> list) {
  final sorted = [...list];
  sorted.sort((a, b) {
    // Compare spent/limit without decimals: a.spent * b.limit vs b.spent * a.limit.
    final byUse = (b.spentCents * a.limitCents).compareTo(
      a.spentCents * b.limitCents,
    );
    if (byUse != 0) return byUse;
    return a.category.name.compareTo(b.category.name);
  });
  return sorted;
}

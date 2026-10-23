import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/budget.dart';
import '../domain/budget_progress.dart';
import 'budgets_repository.dart';

/// The signed-in user's budgets. Screens call the methods below to change
/// them; the list reloads after each change.
final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  BudgetsRepository get _repo => ref.read(budgetsRepositoryProvider);

  @override
  Future<List<Budget>> build() async {
    if (!ref.watch(supabaseReadyProvider)) return [];
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return [];
    return _repo.fetchAll();
  }

  Future<void> add({
    required String? categoryId,
    required String name,
    required int amountCents,
  }) async {
    await _repo.create(
      categoryId: categoryId,
      name: name,
      amountCents: amountCents,
    );
    await _reload();
  }

  Future<void> save(Budget budget) async {
    await _repo.update(budget);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Each budget with how much has been spent against it this month.
/// "All spending" comes first, then the rest from most used to least.
/// Updates on its own when budgets or this month's transactions change.
final budgetProgressProvider = FutureProvider<List<BudgetProgress>>((
  ref,
) async {
  final budgets = await ref.watch(budgetsProvider.future);
  final month = await ref.watch(monthTransactionsProvider.future);
  return sortProgress([
    for (final b in budgets) BudgetProgress.compute(b, month),
  ]);
});

/// "All spending" first, then the most-used budgets.
List<BudgetProgress> sortProgress(List<BudgetProgress> list) {
  final sorted = [...list];
  sorted.sort((a, b) {
    final aAll = a.budget.categoryId == null;
    final bAll = b.budget.categoryId == null;
    if (aAll != bAll) return aAll ? -1 : 1;
    // Compare spent/limit without decimals: a.spent * b.limit vs b.spent * a.limit.
    return (b.spentCents * a.limitCents).compareTo(a.spentCents * b.limitCents);
  });
  return sorted;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/dates.dart';
import '../domain/budget_cycle.dart';

/// All Supabase calls for the `budget_settings` table (one row per user).
class BudgetCycleRepository {
  BudgetCycleRepository(this._client);

  final SupabaseClient _client;

  /// The saved cycle, or null if the user never chose one.
  Future<BudgetCycle?> fetch() async {
    final row = await _client.from('budget_settings').select().maybeSingle();
    return row == null ? null : BudgetCycle.fromRow(row);
  }

  /// Saves the cycle: creates the row the first time, changes it after.
  Future<void> save(String userId, BudgetCycle cycle) async {
    await _client.from('budget_settings').upsert({
      'user_id': userId,
      ...cycle.toRow(),
    }, onConflict: 'user_id');
  }

  /// The dates (newest first, up to 24) of income logged in the Salary
  /// category, not counting any dated after [today].
  Future<List<DateTime>> fetchSalaryDates(DateTime today) async {
    final rows = await _client
        .from('transactions')
        // `!inner` plus the filter below keeps only rows whose category is
        // the user's flagged Salary category.
        .select('occurred_on, categories!inner(is_salary)')
        .eq('kind', 'income')
        .eq('categories.is_salary', true)
        .lte('occurred_on', toDbDate(today))
        .order('occurred_on', ascending: false)
        .limit(24);
    return [for (final r in rows) DateTime.parse(r['occurred_on'] as String)];
  }
}

final budgetCycleRepositoryProvider = Provider<BudgetCycleRepository>(
  (ref) => BudgetCycleRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's budget cycle. Until they choose one (or if it can't
/// be loaded), this is the plain calendar month, so the app always works.
final budgetCycleProvider =
    AsyncNotifierProvider<BudgetCycleNotifier, BudgetCycle>(
      BudgetCycleNotifier.new,
    );

class BudgetCycleNotifier extends AsyncNotifier<BudgetCycle> {
  @override
  Future<BudgetCycle> build() async {
    if (!ref.watch(supabaseReadyProvider)) return BudgetCycle.calendarMonth;
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return BudgetCycle.calendarMonth;
    try {
      final saved = await ref.watch(budgetCycleRepositoryProvider).fetch();
      return saved ?? BudgetCycle.calendarMonth;
    } catch (_) {
      // The setting is optional: if it can't be read (for example, the
      // database isn't updated yet), fall back to the calendar month instead
      // of breaking Home and Budgets.
      return BudgetCycle.calendarMonth;
    }
  }

  /// Saves a new cycle. Throws if it can't be saved, so the sheet can show
  /// the error.
  Future<void> save(BudgetCycle cycle) async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await ref.read(budgetCycleRepositoryProvider).save(user.id, cycle);
    state = AsyncData(cycle);
  }
}

/// When the user logged their salary (newest first). Only used by the
/// salary cycle. Refreshed whenever a transaction is added, edited, or
/// deleted. Empty if there is none or it can't be loaded, so budgets then
/// follow the calendar month.
final salaryDatesProvider = FutureProvider<List<DateTime>>((ref) async {
  if (!ref.watch(supabaseReadyProvider)) return const [];
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return const [];
  try {
    return await ref
        .watch(budgetCycleRepositoryProvider)
        .fetchSalaryDates(DateTime.now());
  } catch (_) {
    return const [];
  }
});

/// The budget period that today falls in, e.g. Oct 15 – Oct 29 (or
/// "since Oct 15" for the salary cycle). Home, Budgets, and the category
/// budgets all use this.
final currentPeriodProvider = FutureProvider<BudgetPeriod>((ref) async {
  final cycle = await ref.watch(budgetCycleProvider.future);
  final now = DateTime.now();
  if (!cycle.isSalary) return cycle.periodAt(now);
  final salaryDates = await ref.watch(salaryDatesProvider.future);
  return cycle.salaryPeriod(now, salaryDates);
});

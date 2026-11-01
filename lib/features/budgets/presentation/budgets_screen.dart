import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../categories/data/categories_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/budget_cycle_provider.dart';
import '../data/budgets_provider.dart';
import '../domain/budget_cycle.dart';
import 'budget_cycle_sheet.dart';
import 'budget_form_sheet.dart';
import 'budget_progress_tile.dart';

/// All budgets for this month, with add (+) and tap-to-edit.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};
    // "for October", "for Oct 15 – Oct 29", or "since Oct 15".
    final period = ref.watch(currentPeriodProvider).value;
    final phrase = periodPhrase(
      period ?? BudgetCycle.calendarMonth.periodAt(DateTime.now()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            tooltip: 'Add budget',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showBudgetFormSheet(context),
          ),
        ],
      ),
      body: progress.when(
        data: (items) => ListView(
          padding: screenPadding(context),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'Limits $phrase. They start over each budget period. '
                'Tap a budget to change it.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (items.isEmpty)
              const NoBudgetsCard()
            else
              BudgetsCard(
                items: items,
                categoriesById: byId,
                onTap: (p) => showBudgetFormSheet(context, existing: p.budget),
              ),
            const SizedBox(height: 20),
            const _BudgetCycleTile(),
          ],
        ),
        loading: () => const SkeletonPage(cards: 1),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your budgets",
          onRetry: () {
            ref.invalidate(budgetsProvider);
            ref.invalidate(monthTransactionsProvider);
          },
        ),
      ),
    );
  }
}

/// "Budget cycle" row: shows when budgets start over, and opens the form
/// to change it.
class _BudgetCycleTile extends ConsumerWidget {
  const _BudgetCycleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycle =
        ref.watch(budgetCycleProvider).value ?? BudgetCycle.calendarMonth;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.event_repeat_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text(
          'Budget cycle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(cycle.summary),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showBudgetCycleSheet(context),
      ),
    );
  }
}

/// Shown when there are no budgets yet, with a button to add the first one.
class NoBudgetsCard extends StatelessWidget {
  const NoBudgetsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.savings_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a monthly limit for Food, Transport, or all your spending, '
              'and watch how close you are.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => showBudgetFormSheet(context),
              child: const Text('Add a budget'),
            ),
          ],
        ),
      ),
    );
  }
}

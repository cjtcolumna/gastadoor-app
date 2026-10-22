import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/screen_padding.dart';
import '../../categories/data/categories_repository.dart';
import '../data/budgets_provider.dart';
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
    final month = DateFormat.MMMM().format(DateTime.now());

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
                'Monthly limits for $month. Tap a budget to change it.',
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
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(budgetsProvider),
            child: const Text('Could not load budgets. Try again'),
          ),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/presentation/category_pill.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/budget_cycle_provider.dart';
import '../data/budgets_provider.dart';
import '../domain/budget_cycle.dart';
import '../domain/budget_progress.dart';
import 'budget_progress_tile.dart';

/// The "Budget" section on Home: a Manage link, then one card with how all
/// your monthly limits are doing together. The categories are on the Budget
/// page, one tap away.
class BudgetHomeSection extends ConsumerWidget {
  const BudgetHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(budgetSummaryProvider);
    final period = ref.watch(currentPeriodProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Budget', style: theme.textTheme.titleMedium),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/budget'),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Not loaded yet is different from "no limits": don't invite
        // someone to set a limit they already have.
        if (!summary.hasValue && summary.hasError)
          ErrorView.inline(
            error: summary.error!,
            title: "Couldn't load your budget",
            onRetry: () {
              ref.invalidate(categoriesProvider);
              ref.invalidate(monthTransactionsProvider);
            },
          )
        else if (!summary.hasValue)
          const SkeletonListCard(rows: 2)
        else if (!summary.requireValue.hasLimits)
          NoBudgetsCard(onSetUp: () => context.go('/budget'))
        else
          _BudgetRingCard(
            totals: summary.requireValue,
            daysLeft: period == null
                ? null
                : daysLeftIn(period, DateTime.now()),
          ),
      ],
    );
  }
}

/// A small ring with the percent used, and next to it what is left. The
/// whole card opens the Budget page.
class _BudgetRingCard extends StatelessWidget {
  const _BudgetRingCard({required this.totals, required this.daysLeft});

  final BudgetSummary totals;

  /// Null when the period has no planned end (the salary cycle).
  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final statusColor = budgetStatusColor(context, totals.status);
    final isOver = totals.status == BudgetStatus.over;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/budget'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BudgetRing(
                size: 72,
                strokeWidth: 8,
                progress: totals.barFraction,
                color: statusColor,
                child: SizedBox(
                  width: 46,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${totals.percentUsed}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        budgetLeftText(totals),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          // Red once you are over; otherwise the normal color.
                          color: isOver ? statusColor : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Money.format(totals.spentCents)} of '
                      '${Money.format(totals.limitCents)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                    if (daysLeft != null)
                      Text(
                        daysLeftText(daysLeft!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

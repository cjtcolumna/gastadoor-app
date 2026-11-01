import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/archived_categories_section.dart';
import '../../categories/presentation/category_form_sheet.dart';
import '../../categories/presentation/category_pill.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/kind_switch.dart';
import '../data/budget_cycle_provider.dart';
import '../data/budgets_provider.dart';
import '../domain/budget_cycle.dart';
import '../domain/budget_progress.dart';
import 'budget_cycle_sheet.dart';
import 'budget_progress_tile.dart';

/// Your categories and their monthly limits, in one place.
///
/// An Expenses | Income switch sits at the top. Expenses show a ring with
/// all your limits together, then each category with its own bar. Income is
/// just the list of income categories: income has no limits.
/// Tap a category to rename it or change its limit, or + to add one.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  TransactionKind _kind = TransactionKind.expense;

  bool get _isExpense => _kind == TransactionKind.expense;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            icon: const Icon(Icons.add_circle_outline_rounded),
            // Adds to whichever side you are looking at.
            onPressed: () => showCategoryFormSheet(context, kind: _kind),
          ),
        ],
      ),
      body: categories.when(
        data: (list) => ListView(
          padding: screenPadding(context),
          children: [
            KindSwitch(
              kind: _kind,
              kinds: const [TransactionKind.expense, TransactionKind.income],
              onChanged: (kind) => setState(() => _kind = kind),
            ),
            const SizedBox(height: 16),
            if (_isExpense) ..._expenseView(list) else ..._incomeView(list),
          ],
        ),
        loading: () => const SkeletonPage(cards: 2),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your categories",
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
    );
  }

  List<Widget> _expenseView(List<Category> all) {
    final expenses = all.where((c) => c.kind == TransactionKind.expense);
    return [
      const _SummaryCard(),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          'Categories',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        child: Text(
          'Tap one to change its name or set a monthly limit.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      _ExpenseList(expenses: expenses.toList()),
      const ArchivedCategoriesSection(kind: TransactionKind.expense),
      const SizedBox(height: 20),
      const _BudgetCycleTile(),
    ];
  }

  List<Widget> _incomeView(List<Category> all) {
    // Salary first (it sets the budget cycle), then the rest by name.
    final income = all.where((c) => c.kind == TransactionKind.income).toList()
      ..sort((a, b) {
        if (a.isSalary != b.isSalary) return a.isSalary ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    return [
      _CategoryCard(
        emptyText: 'No income categories yet.',
        children: [
          for (final c in income)
            _CategoryTile(
              category: c,
              subtitle: c.isSalary ? 'Used for your budget cycle' : null,
            ),
        ],
      ),
      const ArchivedCategoriesSection(kind: TransactionKind.income),
    ];
  }
}

/// The card at the top of Expenses: a ring for all the limits together, or a
/// hint to set one while there are none.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(budgetSummaryProvider);
    final period = ref.watch(currentPeriodProvider).value;

    if (!summary.hasValue) {
      if (summary.hasError) {
        return ErrorView.inline(
          error: summary.error!,
          title: "Couldn't load your budget",
          onRetry: () => ref.invalidate(monthTransactionsProvider),
        );
      }
      return const SkeletonListCard(rows: 3);
    }

    final totals = summary.requireValue;
    if (!totals.hasLimits) {
      return const NoBudgetsCard(
        message:
            'No limits yet. Open a category below and set a monthly limit '
            'to see how close you are.',
      );
    }

    final shown = period ?? BudgetCycle.calendarMonth.periodAt(DateTime.now());
    return _RingCard(
      totals: totals,
      // "for October", "for Oct 15 – Oct 29", or "since Oct 15".
      phrase: periodPhrase(shown),
      daysLeft: daysLeftIn(shown, DateTime.now()),
    );
  }
}

/// One big ring: how much of all your limits is used.
class _RingCard extends StatelessWidget {
  const _RingCard({
    required this.totals,
    required this.phrase,
    required this.daysLeft,
  });

  final BudgetSummary totals;
  final String phrase;

  /// Null when the period has no planned end (the salary cycle).
  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final statusColor = budgetStatusColor(context, totals.status);
    final isOver = totals.status == BudgetStatus.over;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Limits $phrase',
              style: theme.textTheme.titleSmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            BudgetRing(
              size: 176,
              strokeWidth: 14,
              progress: totals.barFraction,
              color: statusColor,
              child: SizedBox(
                width: 116,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.format(totals.spentCents),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'of ${Money.format(totals.limitCents)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                Text(
                  isOver
                      ? '${Money.format(totals.overCents)} over'
                      : '${Money.format(totals.leftCents)} left',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isOver ? statusColor : null,
                  ),
                ),
                if (daysLeft != null) ...[
                  Text('·', style: theme.textTheme.titleMedium),
                  Text(
                    daysLeftText(daysLeft!),
                    style: theme.textTheme.titleMedium?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
            if (totals.outsideCents > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${Money.format(totals.outsideCents)} spent outside your limits',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Expense categories in one card: the ones with a limit first (most used
/// on top, with a bar), then the ones with no limit.
class _ExpenseList extends ConsumerWidget {
  const _ExpenseList({required this.expenses});

  final List<Category> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);

    // Not loaded yet is different from "no limits": don't show every
    // category as "No limit" for a moment.
    if (!progress.hasValue) {
      if (progress.hasError) {
        return ErrorView.inline(
          error: progress.error!,
          title: "Couldn't load your limits",
          onRetry: () => ref.invalidate(monthTransactionsProvider),
        );
      }
      return const SkeletonListCard(rows: 4);
    }

    final withLimit = progress.requireValue;
    final noLimit = expenses.where((c) => c.budgetCents == null);

    return _CategoryCard(
      emptyText: 'No expense categories yet.',
      children: [
        for (final p in withLimit)
          BudgetProgressTile(
            progress: p,
            onTap: () => showCategoryFormSheet(context, existing: p.category),
          ),
        for (final c in noLimit)
          _CategoryTile(category: c, trailing: 'No limit'),
      ],
    );
  }
}

/// A white card with thin lines between [children], or [emptyText] when
/// there are none.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.children, required this.emptyText});

  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: children.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text(emptyText))
          : Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16),
                  child,
                ],
              ],
            ),
    );
  }
}

/// A plain category row: icon, name, and (optionally) a note on the right.
/// Tap it to edit the category.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, this.subtitle, this.trailing});

  final Category category;
  final String? subtitle;

  /// Small grey text before the arrow (for example "No limit").
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CategoryAvatar(icon: category.icon, color: category.color),
      title: Text(
        category.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => showCategoryFormSheet(context, existing: category),
    );
  }
}

/// "Budget cycle" row: shows when limits start over, and opens the form
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

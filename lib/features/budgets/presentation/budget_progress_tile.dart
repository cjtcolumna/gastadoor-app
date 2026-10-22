import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../domain/budget_progress.dart';

/// The color for a budget's status: green, amber, or red.
Color budgetStatusColor(BuildContext context, BudgetStatus status) {
  final money = context.appColors;
  return switch (status) {
    BudgetStatus.ok => money.income,
    BudgetStatus.warning => money.warning,
    BudgetStatus.over => money.expense,
  };
}

/// One budget: icon, name, "₱3,760.00 of ₱5,000.00", what's left (or over),
/// and a colored progress bar.
class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({
    super.key,
    required this.progress,
    required this.category,
    this.onTap,
  });

  final BudgetProgress progress;

  /// The budget's category, or null for an "all spending" budget.
  final Category? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = budgetStatusColor(context, progress.status);
    final isOver = progress.status == BudgetStatus.over;
    final remaining = isOver
        ? '${Money.format(progress.overCents)} over'
        : '${Money.format(progress.leftCents)} left';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _BudgetAvatar(category: category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? 'All spending',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${Money.format(progress.spentCents)} of '
                        '${Money.format(progress.limitCents)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  remaining,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    // Red when over; otherwise a calm grey.
                    color: isOver
                        ? statusColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.barFraction,
                minHeight: 8,
                color: statusColor,
                backgroundColor: statusColor.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetAvatar extends StatelessWidget {
  const _BudgetAvatar({required this.category});

  final Category? category;

  @override
  Widget build(BuildContext context) {
    final c = category;
    if (c != null) return CategoryAvatar(icon: c.icon, color: c.color);
    // "All spending" gets a wallet in the app's green.
    return CircleAvatar(
      backgroundColor: context.appColors.incomeSoft,
      foregroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.account_balance_wallet_rounded, size: 20),
    );
  }
}

/// A white card listing several budgets with thin lines between them.
class BudgetsCard extends StatelessWidget {
  const BudgetsCard({
    super.key,
    required this.items,
    required this.categoriesById,
    this.onTap,
  });

  final List<BudgetProgress> items;
  final Map<String, Category> categoriesById;
  final void Function(BudgetProgress)? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, p) in items.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            BudgetProgressTile(
              progress: p,
              category: categoriesById[p.budget.categoryId],
              onTap: onTap == null ? null : () => onTap!(p),
            ),
          ],
        ],
      ),
    );
  }
}

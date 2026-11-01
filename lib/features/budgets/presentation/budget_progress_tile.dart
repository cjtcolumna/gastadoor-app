import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
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

/// "₱1,240.00 left", or "₱320.00 over" once the limit is passed.
String budgetLeftText(BudgetUsage usage) => usage.status == BudgetStatus.over
    ? '${Money.format(usage.overCents)} over'
    : '${Money.format(usage.leftCents)} left';

/// One category's budget: icon, name, "₱3,760.00 of ₱5,000.00", what's left
/// (or over), and a colored progress bar.
class BudgetProgressTile extends StatelessWidget {
  const BudgetProgressTile({super.key, required this.progress, this.onTap});

  final BudgetProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = progress.category;
    final statusColor = budgetStatusColor(context, progress.status);
    final isOver = progress.status == BudgetStatus.over;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CategoryAvatar(icon: category.icon, color: category.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
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
                // A huge amount shrinks a little instead of pushing the row
                // off a narrow screen.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      budgetLeftText(progress),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        // Red when over; otherwise a calm grey.
                        color: isOver
                            ? statusColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

/// Shown when no category has a limit yet. With [onSetUp] it also has a
/// button (Home uses it to open the Budget page).
class NoBudgetsCard extends StatelessWidget {
  const NoBudgetsCard({
    super.key,
    this.message =
        'Set a monthly limit on Food, Transport, or any category, and watch '
        'how close you are.',
    this.onSetUp,
  });

  final String message;
  final VoidCallback? onSetUp;

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
            Text(message, textAlign: TextAlign.center),
            if (onSetUp != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onSetUp,
                child: const Text('Set a limit'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

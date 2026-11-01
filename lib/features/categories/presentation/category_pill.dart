import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pill_height.dart';
import '../../budgets/domain/budget_progress.dart';
import '../domain/category.dart';
import 'category_visuals.dart';

/// One category as a pill: a ring around its icon, and its name. When the
/// category has a budget, the ring fills up as the budget is used and a tiny
/// "₱0/₱1.5k" (spent this month / limit) sits under the name.
///
/// Selected: a light fill of the category's color and a thin border in it.
/// The height is [pillHeight], the same as an account pill. The width fits
/// the content (a very long name is cut with "...").
class CategoryPill extends StatelessWidget {
  const CategoryPill({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    this.budget,
  });

  final Category category;
  final bool selected;

  /// Null makes the pill untappable.
  final VoidCallback? onTap;

  /// This month's budget for the category, or null when it has none.
  final BudgetProgress? budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColorFor(category.color, theme.colorScheme);
    final budget = this.budget;

    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        height: pillHeight,
        child: Material(
          color: selected
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.16),
                  theme.colorScheme.surface,
                )
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            // A thin border in the category's color marks the picked one.
            side: BorderSide(
              color: selected ? color : context.appColors.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BudgetRing(
                    progress: budget?.barFraction,
                    color: budget == null
                        ? null
                        : _statusColor(context, budget),
                    child: Icon(
                      categoryIconFor(category.icon),
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        if (budget != null)
                          Text(
                            '${Money.formatShort(budget.spentCents)}/'
                            '${Money.formatShort(budget.limitCents)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "+ New" pill at the end of the category pills: the same height and
/// shape as a [CategoryPill], with a plus icon and the word "New".
class NewCategoryPill extends StatelessWidget {
  const NewCategoryPill({super.key, required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'New category',
      child: Semantics(
        button: true,
        label: 'New category',
        excludeSemantics: true,
        child: SizedBox(
          height: pillHeight,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: context.appColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green while the budget is fine, amber from 75% used, red once it is over.
/// (The same statuses as the Budgets screen.)
Color _statusColor(BuildContext context, BudgetProgress budget) {
  final colors = context.appColors;
  return switch (budget.status) {
    BudgetStatus.ok => colors.income,
    BudgetStatus.warning => colors.warning,
    BudgetStatus.over => colors.expense,
  };
}

/// A donut around [child] (the icon). With a [progress] (0 to 1) it is a
/// thin grey track with a colored arc that fills clockwise from the top.
/// Without one (no budget) there is no ring, just the icon, but the box keeps
/// the same size so every pill lines up.
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.child,
    this.progress,
    this.color,
    this.size = 26,
  });

  final Widget child;

  /// How much of the budget is used, 0.0 to 1.0. Null = no budget.
  final double? progress;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: progress == null
            ? null
            : BudgetRingPainter(
                progress: progress,
                color: color ?? Theme.of(context).colorScheme.primary,
                trackColor: context.appColors.border,
              ),
        child: Center(child: child),
      ),
    );
  }
}

/// Draws the ring: a grey track all the way round, and the colored arc on
/// top for the part of the budget used.
class BudgetRingPainter extends CustomPainter {
  const BudgetRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  static const strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    // Keep the stroke inside the box (strokes are centered on the line).
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawOval(rect, paint..color = trackColor);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress.clamp(0, 1), // go clockwise
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(BudgetRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

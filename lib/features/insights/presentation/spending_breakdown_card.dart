import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../transactions/domain/spending_breakdown.dart';

/// "Where your money went": a thin share bar (biggest 5 categories + Other)
/// over a ranked list of categories, each with its own bar, amount, and %.
///
/// The list is also the chart's "table view": every value is written out,
/// and every row is labeled, so nobody has to tell categories apart by
/// color alone.
class SpendingBreakdownCard extends StatelessWidget {
  const SpendingBreakdownCard({
    super.key,
    required this.slices,
    required this.categoriesById,
    this.maxRows,
    this.footer,
  });

  /// Spending per category, biggest first (from `spendingByCategory`).
  final List<CategorySlice> slices;
  final Map<String, Category> categoriesById;

  /// Show only this many rows (Home shows 3). Null shows them all.
  final int? maxRows;

  /// Optional widget under the list (e.g. a "See insights" link).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, s) => sum + s.cents);

    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No spending yet this month.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final rows = maxRows == null ? slices : slices.take(maxRows!).toList();
    final biggest = slices.first.cents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total spent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              Money.format(total),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ShareBar(
              slices: topWithOther(slices),
              total: total,
              categoriesById: categoriesById,
            ),
            const SizedBox(height: 8),
            for (final s in rows)
              _CategoryRow(
                slice: s,
                category: categoriesById[s.categoryId],
                total: total,
                biggest: biggest,
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// The color a slice is drawn in. Categories use their own color;
/// "Uncategorized" and "Other" use quiet greys.
Color sliceColor(CategorySlice slice, Category? category, ColorScheme scheme) {
  if (slice.isOther) return scheme.outlineVariant;
  if (category == null) return scheme.outline;
  return categoryColorFor(category.color, scheme);
}

/// The name shown for a slice.
String sliceName(CategorySlice slice, Category? category) {
  if (slice.isOther) return 'Other';
  return category?.name ?? 'Uncategorized';
}

/// One thin bar split into colored pieces, sized by share of spending,
/// with a 2px white gap between pieces.
class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.slices,
    required this.total,
    required this.categoriesById,
  });

  final List<CategorySlice> slices;
  final int total;
  final Map<String, Category> categoriesById;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Share of spending by category',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 12,
          child: Row(
            // Make each colored piece fill the bar's full height
            // (empty boxes otherwise shrink to nothing).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, s) in slices.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  // flex needs a whole number; cents are already whole.
                  flex: s.cents,
                  child: ColoredBox(
                    color: sliceColor(s, categoriesById[s.categoryId], scheme),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon, name, a bar as long as this category's spending (compared with
/// the biggest one), the amount, and its share of the total.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slice,
    required this.category,
    required this.total,
    required this.biggest,
  });

  final CategorySlice slice;
  final Category? category;
  final int total;
  final int biggest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sliceColor(slice, category, theme.colorScheme);
    // Whole-number percent: round(cents * 100 / total).
    final percent = (slice.cents * 100 + total ~/ 2) ~/ total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryAvatar(
            icon: category?.icon,
            color: category?.color,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sliceName(slice, category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Values in normal text color, not the category color.
                    Text(
                      Money.format(slice.cents),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: slice.cents / biggest,
                          minHeight: 6,
                          color: color,
                          backgroundColor: theme.colorScheme.surfaceContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

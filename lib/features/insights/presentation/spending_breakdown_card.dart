import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../transactions/domain/spending_breakdown.dart';
import 'donut_chart.dart';

/// "Where your money went": a donut chart (biggest 5 categories + Other)
/// with the total in the middle, over a ranked list of categories, each
/// with its own bar, amount, and %.
///
/// Tap a slice to see that category in the middle; tap it again (or the
/// middle) to go back to the total.
///
/// The list is also the chart's "table view": every value is written out,
/// and every row is labeled, so nobody has to tell categories apart by
/// color alone.
class SpendingBreakdownCard extends StatefulWidget {
  const SpendingBreakdownCard({
    super.key,
    required this.slices,
    required this.categoriesById,
    this.maxRows,
    this.footer,
    this.chartSize = 220,
  });

  /// Spending per category, biggest first (from `spendingByCategory`).
  final List<CategorySlice> slices;
  final Map<String, Category> categoriesById;

  /// Show only this many rows (Home shows 3). Null shows them all.
  final int? maxRows;

  /// Optional widget under the list (e.g. a "See insights" link).
  final Widget? footer;

  /// The donut's width (it shrinks on narrow screens).
  final double chartSize;

  @override
  State<SpendingBreakdownCard> createState() => _SpendingBreakdownCardState();
}

class _SpendingBreakdownCardState extends State<SpendingBreakdownCard> {
  /// The tapped slice (index into the donut's slices), or null.
  int? _selected;

  @override
  void didUpdateWidget(SpendingBreakdownCard old) {
    super.didUpdateWidget(old);
    // A different month: start again from the total.
    if (old.slices != widget.slices) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slices = widget.slices;
    final byId = widget.categoriesById;
    final total = slices.fold<int>(0, (sum, s) => sum + s.cents);
    final ring = topWithOther(slices);
    final picked = _selected == null || _selected! >= ring.length
        ? null
        : ring[_selected!];

    final rows = widget.maxRows == null
        ? slices
        : slices.take(widget.maxRows!).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.chartSize),
                child: DonutChart(
                  values: [for (final s in ring) s.cents],
                  colors: [
                    for (final s in ring)
                      sliceColor(s, byId[s.categoryId], scheme),
                  ],
                  trackColor: scheme.surfaceContainerHighest,
                  selected: picked == null ? null : _selected,
                  onSelect: total == 0
                      ? null
                      : (i) => setState(() => _selected = i),
                  semanticLabel: _chartLabel(ring, total),
                  center: _CenterText(
                    total: total,
                    slice: picked,
                    category: picked == null ? null : byId[picked.categoryId],
                  ),
                ),
              ),
            ),
            if (total == 0) ...[
              const SizedBox(height: 12),
              Text(
                'No spending yet this month.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 16),
              for (final s in rows)
                _CategoryRow(
                  slice: s,
                  category: byId[s.categoryId],
                  total: total,
                  biggest: slices.first.cents,
                  highlighted:
                      picked != null &&
                      !picked.isOther &&
                      picked.categoryId == s.categoryId,
                ),
            ],
            ?widget.footer,
          ],
        ),
      ),
    );
  }

  /// What a screen reader says for the chart, e.g.
  /// "Spending chart. Total spent ₱1,000.00. Food 75%, Bills 25%."
  String _chartLabel(List<CategorySlice> ring, int total) {
    if (total == 0) return 'Spending chart. No spending yet.';
    final parts = [
      for (final s in ring)
        '${sliceName(s, widget.categoriesById[s.categoryId])} '
            '${percentOf(s.cents, total)}%',
    ];
    return 'Spending chart. Total spent ${Money.format(total)}. '
        '${parts.join(', ')}.';
  }
}

/// Whole-number percent: round(cents * 100 / total).
int percentOf(int cents, int total) => (cents * 100 + total ~/ 2) ~/ total;

/// The text in the middle of the donut: the total, or the tapped slice.
class _CenterText extends StatelessWidget {
  const _CenterText({required this.total, this.slice, this.category});

  final int total;
  final CategorySlice? slice;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final s = slice;
    final label = s == null ? 'Total spent' : sliceName(s, category);
    final amount = s == null ? total : s.cents;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
        // Shrinks to fit the hole instead of spilling out.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Money.format(amount),
            maxLines: 1,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (s != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${percentOf(s.cents, total)}% of spending',
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
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

/// Icon, name, a bar as long as this category's spending (compared with
/// the biggest one), the amount, and its share of the total.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.slice,
    required this.category,
    required this.total,
    required this.biggest,
    this.highlighted = false,
  });

  final CategorySlice slice;
  final Category? category;
  final int total;
  final int biggest;

  /// True when this category's slice is tapped in the donut.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sliceColor(slice, category, theme.colorScheme);
    final percent = percentOf(slice.cents, total);
    // Text set much bigger than normal on the phone.
    final large = MediaQuery.textScalerOf(context).scale(10) > 13;
    final name = Text(
      sliceName(slice, category),
      maxLines: large ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    // Values in normal text color, not the category color.
    final amount = Text(
      Money.format(slice.cents),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    final percentText = Text(
      '$percent%',
      textAlign: TextAlign.end,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      // A soft tint of the category's color when its slice is tapped.
      decoration: BoxDecoration(
        color: highlighted ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
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
                if (large) ...[
                  name,
                  amount,
                ] else
                  Row(
                    children: [
                      Expanded(child: name),
                      amount,
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
                    // Fixed width keeps the bars lined up; big text gets
                    // as much room as it needs.
                    if (large)
                      percentText
                    else
                      SizedBox(width: 36, child: percentText),
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

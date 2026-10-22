import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';
import '../../transactions/domain/spending_breakdown.dart';

/// Bar colors for the trend chart. Checked with a color-blindness
/// validator: this teal and red stay clearly different for people with
/// red-green color blindness (the app's darker income green did not).
/// Text never uses these colors; it stays in normal ink.
const incomeBarColor = Color(0xFF2A9D8F);
const spendingBarColor = Color(0xFFD64545);

/// Income vs. spending for each month: two thin bars per month on one
/// shared ₱ scale, with a legend above and a tooltip on tap.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points});

  /// Oldest month first.
  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final top = _niceMax(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend: two series, so it's always shown.
        const Row(
          children: [
            _LegendDot(color: incomeBarColor, label: 'Income'),
            SizedBox(width: 16),
            _LegendDot(color: spendingBarColor, label: 'Spending'),
          ],
        ),
        const SizedBox(height: 16),
        // Fixed height that includes the month labels, so nothing scrolls.
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: top.toDouble(),
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (final (i, p) in points.indexed)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2, // the 2px gap between the pair
                    barRods: [
                      _rod(p.totals.incomeCents, incomeBarColor),
                      _rod(p.totals.expenseCents, spendingBarColor),
                    ],
                  ),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: top / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: top / 4,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        Money.formatCompact(value.round()),
                        style: muted,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        DateFormat.MMM().format(points[value.toInt()].month),
                        style: muted,
                      ),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final p = points[group.x];
                    final label = rodIndex == 0 ? 'Income' : 'Spending';
                    final cents = rodIndex == 0
                        ? p.totals.incomeCents
                        : p.totals.expenseCents;
                    return BarTooltipItem(
                      '${DateFormat.yMMM().format(p.month)}\n'
                      '$label ${Money.format(cents)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A thin bar with rounded top corners.
  static BarChartRodData _rod(int cents, Color color) => BarChartRodData(
    toY: cents.toDouble(),
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );

  /// A round top for the scale (e.g. ₱25,000 -> ₱30,000) so the
  /// axis labels are tidy. Never zero, so an empty chart still draws.
  static int _niceMax(List<MonthPoint> points) {
    var max = 0;
    for (final p in points) {
      if (p.totals.incomeCents > max) max = p.totals.incomeCents;
      if (p.totals.expenseCents > max) max = p.totals.expenseCents;
    }
    if (max == 0) return 100000; // ₱1,000
    // Step sizes in cents: ₱100, ₱500, ₱1K, ₱5K, ₱10K, ...
    var step = 10000;
    while (max / step > 4) {
      step *= step.toString().startsWith('1') ? 5 : 2;
    }
    return ((max + step - 1) ~/ step) * step;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

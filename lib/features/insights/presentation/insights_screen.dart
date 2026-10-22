import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../categories/data/categories_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/month_totals.dart';
import '../../transactions/domain/spending_breakdown.dart';
import 'spending_breakdown_card.dart';
import 'trend_chart.dart';

/// Charts: where the money went in a chosen month, and the 6-month trend.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  /// First day of the month being shown. Starts at this month.
  DateTime _month = thisMonth();

  bool get _isThisMonth => _month == thisMonth();

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthTxns = ref.watch(transactionsInMonthProvider(_month));
    final trend = ref.watch(sixMonthTrendProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: screenPadding(context),
        children: [
          // ‹ October 2026 ›  (can't go past this month)
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shiftMonth(-1),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _isThisMonth ? null : () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          monthTxns.when(
            data: (txns) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthStats(totals: MonthTotals.from(txns)),
                const SizedBox(height: 12),
                SpendingBreakdownCard(
                  slices: spendingByCategory(txns),
                  categoriesById: byId,
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              child: ListTile(
                title: const Text('Could not load this month.'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.invalidate(transactionsInMonthProvider(_month)),
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Last 6 months', style: theme.textTheme.titleMedium),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TrendChart(points: trend),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small numbers for the month: income, spent, and what's left.
class _MonthStats extends StatelessWidget {
  const _MonthStats({required this.totals});

  final MonthTotals totals;

  @override
  Widget build(BuildContext context) {
    final money = context.appColors;
    final net = totals.incomeCents - totals.expenseCents;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Income',
            value: Money.format(totals.incomeCents),
            color: money.income,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: 'Spent',
            value: Money.format(totals.expenseCents),
            color: money.expense,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(
            label: net < 0 ? 'Short by' : 'Saved',
            value: Money.format(net.abs()),
            color: net < 0 ? money.expense : null,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

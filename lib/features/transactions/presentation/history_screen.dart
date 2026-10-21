import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../categories/presentation/category_visuals.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction.dart';
import '../domain/transaction_page.dart';
import 'transaction_form_sheet.dart';

/// The History tab: your transactions, newest first, 20 per page.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Which page is showing. 0 is the first page.
  int _page = 0;

  void _goTo(int page) => setState(() => _page = page);

  Future<void> _refresh() async {
    ref.invalidate(historyPageProvider);
    await ref.read(historyPageProvider(_page).future);
  }

  @override
  Widget build(BuildContext context) {
    final pageData = ref.watch(historyPageProvider(_page));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: pageData.when(
          // While the next page loads, keep showing the old one.
          skipLoadingOnReload: true,
          data: (page) => page.totalCount == 0
              ? const _EmptyState()
              : _HistoryList(page: page, onPageChanged: _goTo),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(onRetry: _refresh),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.page, required this.onPageChanged});

  final TransactionPage page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: screenPadding(context),
      children: [
        // One small heading + card per day: "Today", "Yesterday", "Oct 20"...
        for (final (day, items) in groupByDay(page.items)) ...[
          _DayHeader(day: day, items: items),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  _TransactionTile(item: item),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        _PaginationBar(page: page, onPageChanged: onPageChanged),
      ],
    );
  }
}

/// "Today" on the left, that day's net total on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});

  final DateTime day;
  final List<TransactionListItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = items.fold<int>(0, (sum, item) {
      final t = item.transaction;
      return t.kind == TransactionKind.income
          ? sum + t.amountCents
          : sum - t.amountCents;
    });
    final muted = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(friendlyDate(day), style: muted)),
          Text(
            '${net < 0 ? '−' : '+'} ${Money.format(net.abs())}',
            style: muted,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context) {
    final money = context.appColors;
    final t = item.transaction;
    final isExpense = t.kind == TransactionKind.expense;
    final title = item.categoryName ?? (isExpense ? 'Expense' : 'Income');
    final details = [item.accountName, if (t.note != null) t.note!];

    return ListTile(
      // The category's icon and color, or a plain arrow if there's none.
      leading: item.categoryName != null
          ? CategoryAvatar(icon: item.categoryIcon, color: item.categoryColor)
          : CircleAvatar(
              backgroundColor: isExpense ? money.expenseSoft : money.incomeSoft,
              foregroundColor: isExpense ? money.expense : money.income,
              child: Icon(
                isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
              ),
            ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        details.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isExpense ? '−' : '+'} ${Money.format(t.amountCents)}',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          // Red for money out, green for money in.
          color: isExpense ? money.expense : money.income,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: () => showTransactionFormSheet(context, existing: t),
    );
  }
}

/// "‹ Prev   Page 2 of 3   Next ›" plus "Showing 21–40 of 45".
class _PaginationBar extends StatelessWidget {
  const _PaginationBar({required this.page, required this.onPageChanged});

  final TransactionPage page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (first, last) = page.shownRange;

    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: page.hasPrevious
                  ? () => onPageChanged(page.page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Prev'),
            ),
            Expanded(
              child: Text(
                'Page ${page.page + 1} of ${page.pageCount}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              onPressed: page.hasNext
                  ? () => onPageChanged(page.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              iconAlignment: IconAlignment.end, // icon after the word
              label: const Text('Next'),
            ),
          ],
        ),
        Text(
          'Showing $first–$last of ${page.totalCount}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // A ListView (not a Column) so pull-to-refresh still works when empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.receipt_long_rounded, size: 48),
        SizedBox(height: 12),
        Text(
          'No expenses yet.\nTap + below to add your first one.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load your history.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

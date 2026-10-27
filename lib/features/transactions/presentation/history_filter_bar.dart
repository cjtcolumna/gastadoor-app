import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_avatar.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/presentation/category_visuals.dart';
import '../data/transactions_repository.dart';
import '../domain/history_filter.dart';
import '../domain/transaction.dart';

/// The search box and one row of filter chips above the History list.
class HistoryFilterBar extends ConsumerWidget {
  const HistoryFilterBar({
    super.key,
    required this.filter,
    required this.searchController,
    required this.onSearchChanged,
    required this.onChanged,
  });

  final HistoryFilter filter;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Say the type (<Account>) explicitly: without it, Dart treats this list
    // as "anything" (dynamic), and `account.type.icon` (an extension) then
    // crashes when the Account chip is tapped.
    // Each main account followed by its pockets; archived ones last.
    final accounts = <Account>[
      ...inGroupOrder(ref.watch(accountsProvider).value ?? const []),
      ...inGroupOrder(ref.watch(archivedAccountsProvider).value ?? const []),
    ];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final account = accounts.where((a) => a.id == filter.accountId).firstOrNull;
    final category = categories
        .where((c) => c.id == filter.categoryId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search notes, e.g. Jollibee',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
            ),
          ),
        ),
        // One scrollable row of chips, so they never wrap or squeeze.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(
                label: filter.month == null
                    ? 'All time'
                    : DateFormat.yMMM().format(filter.month!),
                icon: Icons.calendar_month_rounded,
                active: filter.month != null,
                onTap: () => _pickMonth(context),
              ),
              _FilterChip(
                label: switch (filter.kind) {
                  null => 'Type',
                  TransactionKind.expense => 'Expenses',
                  TransactionKind.income => 'Income',
                  TransactionKind.transfer => 'Transfers',
                },
                icon: Icons.swap_vert_rounded,
                active: filter.kind != null,
                onTap: () => _pickKind(context),
              ),
              _FilterChip(
                label: account == null
                    ? 'Account'
                    : accountLabel(account, accounts),
                icon: Icons.account_balance_wallet_rounded,
                active: filter.accountId != null,
                onTap: () => _pick<String>(
                  context,
                  title: 'Account',
                  current: filter.accountId,
                  options: [
                    for (final a in accounts)
                      _Option(
                        a.id,
                        a.archived
                            ? '${accountLabel(a, accounts)} (archived)'
                            : accountLabel(a, accounts),
                        AccountAvatar(account: a, size: 28),
                      ),
                  ],
                  onPicked: (id) =>
                      onChanged(filter.copyWith(accountId: () => id)),
                ),
              ),
              _FilterChip(
                label: category?.name ?? 'Category',
                icon: Icons.category_rounded,
                active: filter.categoryId != null,
                onTap: () => _pick<String>(
                  context,
                  title: 'Category',
                  current: filter.categoryId,
                  options: [
                    for (final c in categories)
                      _Option(
                        c.id,
                        c.name,
                        CategoryAvatar(
                          icon: c.icon,
                          color: c.color,
                          radius: 14,
                        ),
                      ),
                  ],
                  onPicked: (id) =>
                      onChanged(filter.copyWith(categoryId: () => id)),
                ),
              ),
              if (filter.activeCount > 0)
                ActionChip(
                  avatar: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Clear'),
                  onPressed: () =>
                      onChanged(HistoryFilter(search: filter.search)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _pickMonth(BuildContext context) {
    final now = thisMonth();
    _pick<DateTime>(
      context,
      title: 'Month',
      current: filter.month,
      options: [
        for (var i = 0; i < 12; i++)
          _Option(
            DateTime(now.year, now.month - i),
            DateFormat.yMMMM().format(DateTime(now.year, now.month - i)),
            null,
          ),
      ],
      noneLabel: 'All time',
      onPicked: (m) => onChanged(filter.copyWith(month: () => m)),
    );
  }

  void _pickKind(BuildContext context) {
    _pick<TransactionKind>(
      context,
      title: 'Type',
      current: filter.kind,
      options: const [
        _Option(
          TransactionKind.expense,
          'Expenses',
          Icon(Icons.north_east_rounded),
        ),
        _Option(
          TransactionKind.income,
          'Income',
          Icon(Icons.south_west_rounded),
        ),
        _Option(
          TransactionKind.transfer,
          'Transfers',
          Icon(Icons.swap_horiz_rounded),
        ),
      ],
      noneLabel: 'All types',
      onPicked: (k) => onChanged(filter.copyWith(kind: () => k)),
    );
  }

  /// A list of choices that slides up. The first row clears the filter.
  /// Picking a row closes it and passes the choice back.
  void _pick<T>(
    BuildContext context, {
    required String title,
    required T? current,
    required List<_Option<T>> options,
    required ValueChanged<T?> onPicked,
    String noneLabel = 'Any',
  }) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        void choose(T? value) {
          Navigator.pop(sheetContext);
          onPicked(value);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              _OptionTile(
                label: noneLabel,
                leading: const Icon(Icons.all_inclusive_rounded),
                selected: current == null,
                onTap: () => choose(null),
              ),
              for (final o in options)
                _OptionTile(
                  label: o.label,
                  leading: o.leading,
                  selected: o.value == current,
                  onTap: () => choose(o.value),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Option<T> {
  const _Option(this.value, this.label, this.leading);

  final T value;
  final String label;
  final Widget? leading;
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: leading,
      title: Text(
        label,
        style: TextStyle(fontWeight: selected ? FontWeight.w700 : null),
      ),
      trailing: selected ? Icon(Icons.check_rounded, color: primary) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}

/// A chip that shows the current choice; tinted when a filter is on.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
        selected: active,
        selectedColor: scheme.primaryContainer,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

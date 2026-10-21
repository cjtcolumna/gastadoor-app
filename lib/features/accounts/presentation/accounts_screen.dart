import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/screen_padding.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_balance_tile.dart';
import 'account_form_sheet.dart';

/// The Accounts tab: lists accounts (Cash, GCash, BDO...) and lets you
/// add, edit, or archive them.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Add account',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => showAccountFormSheet(context),
          ),
        ],
      ),
      body: accounts.when(
        data: (list) =>
            list.isEmpty ? const _EmptyState() : _AccountsList(accounts: list),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            _ErrorState(onRetry: () => ref.invalidate(accountsProvider)),
      ),
    );
  }
}

class _AccountsList extends ConsumerWidget {
  const _AccountsList({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final balances = ref.watch(accountBalancesProvider).value ?? const {};

    return ListView(
      padding: screenPadding(context),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total balance',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                Money.format(netWorthCents(accounts, balances)),
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AccountsCard(
          children: [
            for (final account in accounts)
              AccountBalanceTile(
                account: account,
                balanceCents: balanceOf(account, balances),
                onTap: () => showAccountFormSheet(context, account: account),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Tap an account to rename it or change its starting balance.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No accounts yet.\nTap + at the top to add Cash, GCash, or a bank.',
          textAlign: TextAlign.center,
        ),
      ),
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
          const Text('Could not load your accounts.'),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/balances.dart';
import '../../accounts/presentation/account_balance_tile.dart';
import '../../auth/data/auth_repository.dart';
import '../../transactions/data/transactions_repository.dart';

/// The Home tab: a dashboard with your net worth and each account's balance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountsProvider);
    ref.invalidate(monthSpentCentsProvider);
    await ref.read(accountBalancesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final signedIn = ref.watch(currentUserProvider).value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GastaDoor'),
        actions: [if (signedIn) const _SignOutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: screenPadding(context),
          children: [
            const _NetWorthCard(),
            const SizedBox(height: 24),
            const _AccountsSection(),
            if (!supabaseReady) ...[
              const SizedBox(height: 16),
              const _SetupHint(),
            ],
          ],
        ),
      ),
    );
  }
}

/// The big card at the top: net worth, plus this month's spending.
class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    final spent = ref.watch(monthSpentCentsProvider).value;
    final month = DateFormat.MMMM().format(DateTime.now());
    final netWorth = netWorthCents(accounts, balances);
    final onCard = colors.onPrimary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net worth',
            style: theme.textTheme.titleMedium?.copyWith(
              color: onCard.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(netWorth),
              style: theme.textTheme.displaySmall?.copyWith(
                color: onCard,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${accounts.length} '
            '${accounts.length == 1 ? 'account' : 'accounts'}'
            '${spent == null ? '' : '  ·  Spent in $month: ${Money.format(spent)}'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onCard.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Accounts" heading with a Manage link, then a row per account.
class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);
    final balances = ref.watch(accountBalancesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Accounts', style: theme.textTheme.titleMedium),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/accounts'),
              child: const Text('Manage'),
            ),
          ],
        ),
        accounts.when(
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts yet.'),
                )
              : AccountsCard(
                  children: [
                    for (final account in list)
                      AccountBalanceTile(
                        account: account,
                        balanceCents: balanceOf(
                          account,
                          balances.value ?? const {},
                        ),
                      ),
                  ],
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'Could not load your accounts.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        if (balances.hasError)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Showing starting balances. Could not load current balances. '
              'Has the account_balances migration been run?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _SetupHint extends StatelessWidget {
  const _SetupHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Supabase is not configured'),
        subtitle: Text(
          'Copy env.example.json to env.json, add your project URL '
          'and publishable key, then run with --dart-define-from-file=env.json.',
        ),
      ),
    );
  }
}

/// Signs the user out. The router then sends them back to the login screen.
class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout),
      onPressed: () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

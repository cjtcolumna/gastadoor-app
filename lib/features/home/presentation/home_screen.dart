import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/domain/balances.dart';
import '../../accounts/presentation/account_balance_tile.dart';
import '../../budgets/data/budgets_provider.dart';
import '../../budgets/presentation/budget_form_sheet.dart';
import '../../budgets/presentation/budget_progress_tile.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../categories/data/categories_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../insights/presentation/spending_breakdown_card.dart';
import '../../transactions/domain/month_totals.dart';
import '../../transactions/domain/spending_breakdown.dart';

/// The Home tab: a dashboard with your net worth, this month's income and
/// spending, and each account's balance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountsProvider);
    ref.invalidate(monthTransactionsProvider);
    await ref.read(accountBalancesProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final signedIn = ref.watch(currentUserProvider).value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GastaDoor'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.go('/settings'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: screenPadding(context),
          children: [
            const _NetWorthCard(),
            const SizedBox(height: 12),
            const _MonthSummary(),
            const SizedBox(height: 28),
            const _BudgetsSection(),
            const SizedBox(height: 28),
            const _SpendingSection(),
            const SizedBox(height: 28),
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

/// The green card at the top with your net worth.
class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    final netWorth = netWorthCents(accounts, balances);
    const onCard = Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF256B4D), Color(0xFF3A9B6F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net worth',
            style: theme.textTheme.titleSmall?.copyWith(
              color: onCard.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(netWorth),
              style: theme.textTheme.displaySmall?.copyWith(
                color: onCard,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Across ${accounts.length} '
            '${accounts.length == 1 ? 'account' : 'accounts'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onCard.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two small cards: money in (green) and money out (red) this month.
class _MonthSummary extends ConsumerWidget {
  const _MonthSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final totals = ref.watch(monthTotalsProvider).value ?? MonthTotals.zero;
    final month = DateFormat.MMMM().format(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Income · $month',
            cents: totals.incomeCents,
            icon: Icons.south_west_rounded,
            color: colors.income,
            softColor: colors.incomeSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Spent · $month',
            cents: totals.expenseCents,
            icon: Icons.north_east_rounded,
            color: colors.expense,
            softColor: colors.expenseSoft,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.cents,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final String label;
  final int cents;
  final IconData icon;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: softColor,
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(cents),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Accounts" heading with a Manage link, then a row per account.
/// "Budgets" heading with a Manage link, then a progress bar per budget.
class _BudgetsSection extends ConsumerWidget {
  const _BudgetsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(budgetProgressProvider);
    final progress = progressAsync.value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Budgets', style: theme.textTheme.titleMedium),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/budgets'),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Not loaded yet is different from "no budgets": don't invite
        // someone to add a budget they already have.
        if (!progressAsync.hasValue && progressAsync.hasError)
          ErrorView.inline(
            error: progressAsync.error!,
            title: "Couldn't load your budgets",
            onRetry: () {
              ref.invalidate(budgetsProvider);
              ref.invalidate(monthTransactionsProvider);
            },
          )
        else if (!progressAsync.hasValue)
          const SkeletonListCard(rows: 2)
        else if (progress.isEmpty)
          const NoBudgetsCard()
        else
          BudgetsCard(
            items: progress,
            categoriesById: byId,
            onTap: (p) => showBudgetFormSheet(context, existing: p.budget),
          ),
      ],
    );
  }
}

/// "Where your money went" this month: the top 3 categories, with a link
/// to the full Insights page.
class _SpendingSection extends ConsumerWidget {
  const _SpendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthAsync = ref.watch(monthTransactionsProvider);
    final month = monthAsync.value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final byId = {for (final c in categories) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Where your money went',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/insights'),
              child: const Text('Insights'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!monthAsync.hasValue && monthAsync.hasError)
          ErrorView.inline(
            error: monthAsync.error!,
            title: "Couldn't load this month",
            onRetry: () => ref.invalidate(monthTransactionsProvider),
          )
        else if (!monthAsync.hasValue)
          const SkeletonListCard(rows: 3)
        else
          SpendingBreakdownCard(
            slices: spendingByCategory(month),
            categoriesById: byId,
            maxRows: 3,
          ),
      ],
    );
  }
}

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
        const SizedBox(height: 4),
        accounts.when(
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts yet.'),
                )
              : AccountsCard(
                  children: [
                    // One row per main account, showing its total
                    // (its own money plus its sub-accounts).
                    for (final group in groupAccounts(list))
                      AccountBalanceTile(
                        account: group.account,
                        balanceCents: group.totalCents(
                          balances.value ?? const {},
                        ),
                        subtitle: groupSubtitle(group),
                      ),
                  ],
                ),
          loading: () => const SkeletonListCard(rows: 3),
          error: (e, _) => ErrorView.inline(
            error: e,
            title: "Couldn't load your accounts",
            onRetry: () => ref.invalidate(accountsProvider),
          ),
        ),
        if (balances.hasError)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Showing starting balances. Could not load current balances. '
              'Has the account_balances migration been run?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.expense,
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
    return const Card(
      child: ListTile(
        leading: Icon(Icons.info_outline_rounded),
        title: Text('Supabase is not configured'),
        subtitle: Text(
          'Copy env.example.json to env.json, add your project URL '
          'and publishable key, then run with --dart-define-from-file=env.json.',
        ),
      ),
    );
  }
}

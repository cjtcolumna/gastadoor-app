import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_balance_tile.dart';
import 'account_form_sheet.dart';
import 'account_type_ui.dart';

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
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showAccountFormSheet(context),
          ),
        ],
      ),
      body: accounts.when(
        // Always show the list, so the Archived section is reachable
        // even when every account is archived.
        data: (list) => _AccountsList(accounts: list),
        loading: () => const SkeletonPage(),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your accounts",
          onRetry: () => ref.invalidate(accountsProvider),
        ),
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

    if (accounts.isEmpty) {
      return ListView(
        padding: screenPadding(context),
        children: const [_EmptyState(), _ArchivedSection()],
      );
    }

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
        const _ArchivedSection(),
      ],
    );
  }
}

/// "Archived (2)": a closed-by-default section listing archived accounts,
/// each with a Restore button. Hidden when there are none.
class _ArchivedSection extends ConsumerStatefulWidget {
  const _ArchivedSection();

  @override
  ConsumerState<_ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends ConsumerState<_ArchivedSection> {
  /// Whether the section is open, so the arrow can turn to match.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final archived = ref.watch(archivedAccountsProvider).value ?? const [];
    if (archived.isEmpty) return const SizedBox.shrink();
    final balances = ref.watch(accountBalancesProvider).value ?? const {};

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.inventory_2_rounded),
          title: Text('Archived (${archived.length})'),
          subtitle: const Text('Not counted in your net worth'),
          // Our own rounded arrow (Flutter's default one isn't rounded).
          // It turns upside down when the section opens.
          trailing: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded),
          ),
          onExpansionChanged: (open) => setState(() => _open = open),
          // No extra lines at the top/bottom when it opens.
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            for (final account in archived) ...[
              const Divider(height: 1),
              _ArchivedTile(
                account: account,
                balanceCents: balanceOf(account, balances),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchivedTile extends ConsumerStatefulWidget {
  const _ArchivedTile({required this.account, required this.balanceCents});

  final Account account;
  final int balanceCents;

  @override
  ConsumerState<_ArchivedTile> createState() => _ArchivedTileState();
}

class _ArchivedTileState extends ConsumerState<_ArchivedTile> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    Object? failure;
    try {
      await ref.read(accountsProvider.notifier).restore(widget.account.id);
    } catch (e) {
      failure = e;
    }
    // Usually this row disappears after a restore; if it's still here,
    // stop the spinner either way.
    if (!mounted) return;
    setState(() => _restoring = false);
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        child: Icon(widget.account.type.icon, size: 22),
      ),
      title: Text(widget.account.name),
      subtitle: Text(Money.format(widget.balanceCents)),
      trailing: _restoring
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : TextButton(onPressed: _restore, child: const Text('Restore')),
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

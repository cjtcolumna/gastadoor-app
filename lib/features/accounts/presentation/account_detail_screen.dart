import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_form_sheet.dart';
import 'account_type_ui.dart';
import 'pocket_actions_sheet.dart';
import 'pocket_bubble.dart';
import 'pocket_form_sheet.dart';

/// One main account's page (e.g. GoTyme): its main balance on top, and its
/// sub-accounts as bubbles underneath, two per row.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return accounts.when(
      loading: () => Scaffold(appBar: AppBar(), body: const SkeletonPage()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: e,
          title: "Couldn't load this account",
          onRetry: () => ref.invalidate(accountsProvider),
        ),
      ),
      data: (list) {
        final account = list.where((a) => a.id == accountId).firstOrNull;
        if (account == null) {
          return Scaffold(appBar: AppBar(), body: const _NotFound());
        }
        final pockets = list.where((a) => a.parentId == accountId).toList();
        return _AccountPage(account: account, pockets: pockets);
      },
    );
  }
}

class _AccountPage extends ConsumerWidget {
  const _AccountPage({required this.account, required this.pockets});

  final Account account;
  final List<Account> pockets;

  /// Opens the edit form. If the account was archived there, leave this
  /// page (it no longer has anything to show).
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await showAccountFormSheet(context, account: account);
    if (!context.mounted) return;
    final active = ref.read(accountsProvider).value ?? const <Account>[];
    if (!active.any((a) => a.id == account.id)) context.go('/accounts');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: 'Edit account',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _edit(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: screenPadding(context),
        children: [
          _BalanceCard(
            account: account,
            mainCents: balanceOf(account, balances),
            totalCents: netWorthCents([account, ...pockets], balances),
            hasPockets: pockets.isNotEmpty,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Sub-accounts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (pockets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'Set money aside for travel, emergencies, or anything '
                "you're saving for. Each one can have its own goal.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          TwoPerRow(
            children: [
              for (final pocket in pockets)
                PocketBubble(
                  pocket: pocket,
                  balanceCents: balanceOf(pocket, balances),
                  onTap: () => showPocketActions(
                    context,
                    parent: account,
                    pocket: pocket,
                    balanceCents: balanceOf(pocket, balances),
                  ),
                ),
              AddPocketBubble(
                onTap: () => showPocketFormSheet(context, parent: account),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The white card on top: the main balance in big numbers, and the total
/// including sub-accounts under it.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.account,
    required this.mainCents,
    required this.totalCents,
    required this.hasPockets,
  });

  final Account account;
  final int mainCents;
  final int totalCents;
  final bool hasPockets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    Color amountColor(int cents) =>
        cents < 0 ? colors.expense : theme.colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.incomeSoft,
                  foregroundColor: theme.colorScheme.primary,
                  child: Icon(account.type.icon, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  account.type.label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Main balance',
              style: theme.textTheme.titleSmall?.copyWith(color: muted),
            ),
            // Shrinks a little on narrow screens instead of splitting
            // the number over two lines.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(mainCents),
                maxLines: 1,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor(mainCents),
                ),
              ),
            ),
            if (hasPockets) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Text(
                    'Total with sub-accounts',
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Money.format(totalCents),
                      maxLines: 1,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: amountColor(totalCents),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lays [children] out two per row, each taking half the width.
/// An odd one out sits on the left with an empty space beside it.
class TwoPerRow extends StatelessWidget {
  const TwoPerRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "This account isn't here anymore. It may have been archived.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/accounts'),
              child: const Text('Back to accounts'),
            ),
          ],
        ),
      ),
    );
  }
}

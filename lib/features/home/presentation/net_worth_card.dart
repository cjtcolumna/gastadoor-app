import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/balances.dart';
import '../../loans/data/loans_provider.dart';
import '../../loans/domain/loan_summary.dart';

/// The green card at the top of Home.
///
/// Net worth is what is in your accounts plus what people still owe you, so
/// lending money doesn't look like losing it. While someone owes you, two
/// small chips show the two parts. When nobody does, the card is just the
/// total and how many accounts it is across.
class NetWorthCard extends ConsumerWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    // If loans can't be loaded, the card still works: just accounts.
    final loans = ref.watch(loansProvider).value ?? const [];

    final inAccounts = netWorthCents(accounts, balances);
    final owed = totalOwedCents(loans);
    final accountsWord =
        '${accounts.length} '
        '${accounts.length == 1 ? 'account' : 'accounts'}';
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
              Money.format(inAccounts + owed),
              style: theme.textTheme.displaySmall?.copyWith(
                color: onCard,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (owed == 0)
            Text(
              'Across $accountsWord',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onCard.withValues(alpha: 0.8),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            // Both chips are as tall as the taller one.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _HeroChip(
                      label: 'In $accountsWord',
                      cents: inAccounts,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroChip(
                      label: 'Owed to you',
                      cents: owed,
                      overdue: overdueCount(loans),
                      onTap: () => context.go('/loans'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small, see-through box on the green card: a label and an amount.
/// With [onTap] it also shows an arrow and can be pressed.
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.cents,
    this.overdue = 0,
    this.onTap,
  });

  final String label;
  final int cents;

  /// How many loans are overdue, shown as an amber note (0 = no note).
  final int overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onCard = Colors.white;
    final soft = onCard.withValues(alpha: 0.85);

    return Material(
      color: onCard.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: soft),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded, size: 16, color: soft),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(cents),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: onCard,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (overdue > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$overdue overdue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      // A light amber, readable on the dark green.
                      color: Color.lerp(
                        context.appColors.warning,
                        Colors.white,
                        0.5,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

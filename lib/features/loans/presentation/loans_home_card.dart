import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/loans_provider.dart';
import '../domain/loan_summary.dart';
import 'loans_screen.dart';

/// The "Loans" section on Home: a Manage link, then how much is owed to you.
class LoansHomeSection extends ConsumerWidget {
  const LoansHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loans = ref.watch(loansProvider);
    final items = loans.value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Loans', style: theme.textTheme.titleMedium),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/loans'),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!loans.hasValue && loans.hasError)
          ErrorView.inline(
            error: loans.error!,
            title: "Couldn't load your loans",
            onRetry: () => ref.invalidate(loansProvider),
          )
        else if (!loans.hasValue)
          const SkeletonListCard(rows: 1)
        else if (items.isEmpty)
          const NoLoansCard()
        else
          _OwedToYouCard(items: items),
      ],
    );
  }
}

/// A tappable card with the total still owed to you.
class _OwedToYouCard extends StatelessWidget {
  const _OwedToYouCard({required this.items});

  final List<LoanWithPayments> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final people = groupByPerson(items).where((g) => !g.settled).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.go('/loans'),
        // Money owed to you is an asset: soft green with the income green.
        leading: CircleAvatar(
          backgroundColor: colors.incomeSoft,
          foregroundColor: colors.income,
          child: const Icon(Icons.handshake_rounded),
        ),
        title: const Text('Owed to you'),
        subtitle: Text(
          people == 0
              ? 'Nobody owes you right now'
              : 'From $people ${people == 1 ? 'person' : 'people'}',
        ),
        trailing: Text(
          Money.format(totalOwedCents(items)),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.income,
          ),
        ),
      ),
    );
  }
}

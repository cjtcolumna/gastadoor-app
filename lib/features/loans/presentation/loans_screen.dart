import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/loans_provider.dart';
import '../domain/loan_summary.dart';
import 'loan_form_sheet.dart';

/// Everyone who owes you money, with each loan and what is still owed.
class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: [
          IconButton(
            tooltip: 'Lend money',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => showLoanFormSheet(context),
          ),
        ],
      ),
      body: loans.when(
        data: (items) => ListView(
          padding: screenPadding(context),
          children: [
            _OwedCard(items: items),
            const SizedBox(height: 20),
            if (items.isEmpty)
              const NoLoansCard()
            else
              for (final group in groupByPerson(items)) ...[
                _PersonSection(group: group),
                const SizedBox(height: 20),
              ],
          ],
        ),
        loading: () => const SkeletonPage(cards: 2),
        error: (e, _) => ErrorView(
          error: e,
          title: "Couldn't load your loans",
          onRetry: () => ref.invalidate(loansProvider),
        ),
      ),
    );
  }
}

/// The big "Owed to you" total at the top.
class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.items});

  final List<LoanWithPayments> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final people = groupByPerson(items).where((g) => !g.settled).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owed to you',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(totalOwedCents(items)),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              people == 0
                  ? 'Nobody owes you right now'
                  : 'From $people ${people == 1 ? 'person' : 'people'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One borrower: their name and total, then a row for each loan.
class _PersonSection extends StatelessWidget {
  const _PersonSection({required this.group});

  final PersonLoans group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.person,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                group.settled
                    ? 'All paid back'
                    : '${Money.format(group.owedCents)} owed',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: group.settled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [for (final loan in group.loans) LoanTile(loan: loan)],
          ),
        ),
      ],
    );
  }
}

/// One loan: what is left, the original amount, and its status.
class LoanTile extends StatelessWidget {
  const LoanTile({super.key, required this.loan});

  final LoanWithPayments loan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final status = loan.statusOn(DateTime.now());
    final statusColor = switch (status) {
      LoanStatus.overdue => colors.expense,
      LoanStatus.paid => colors.income,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return ListTile(
      // Loans can be opened from Home (/loans) or More (/more/loans), so add
      // the loan's id to whichever address this screen is on.
      onTap: () =>
          context.go('${GoRouterState.of(context).uri.path}/${loan.loan.id}'),
      title: Text(
        loan.isPaid
            ? Money.format(loan.loan.amountCents)
            : Money.format(loan.remainingCents),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Lent ${friendlyDate(loan.loan.lentOn)} · '
        'of ${Money.format(loan.loan.amountCents)}\n'
        '${statusLine(loan)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      isThreeLine: true,
      trailing: Icon(
        status == LoanStatus.paid
            ? Icons.check_circle_rounded
            : Icons.chevron_right_rounded,
        color: statusColor,
      ),
    );
  }
}

/// Shown when there are no loans yet, with a button to add the first one.
class NoLoansCard extends StatelessWidget {
  const NoLoansCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.handshake_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text(
              'Lent money to a friend? Add it here to see who still owes '
              'you, and record each time they pay you back.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => showLoanFormSheet(context),
              child: const Text('Lend money'),
            ),
          ],
        ),
      ),
    );
  }
}

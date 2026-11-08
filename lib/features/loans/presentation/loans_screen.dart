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
import 'loan_status_pill.dart';

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

/// The big "Owed to you" total at the top. Money owed to you is an asset, so
/// it is green: a soft green card with the amount in the income green.
class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.items});

  final List<LoanWithPayments> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final people = groupByPerson(items).where((g) => !g.settled).length;

    return Card(
      color: colors.incomeSoft,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: colors.income,
              child: const Icon(Icons.handshake_rounded, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owed to you',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(totalOwedCents(items)),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.income,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
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
          ],
        ),
      ),
    );
  }
}

/// One borrower: a letter circle, their name and total, then a row for each
/// loan.
class _PersonSection extends StatelessWidget {
  const _PersonSection({required this.group});

  final PersonLoans group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final name = group.person;
    final initial = name.isEmpty
        ? '?'
        : String.fromCharCode(name.runes.first).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              // Same soft-green letter circle as the profile in Settings.
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.incomeSoft,
                foregroundColor: theme.colorScheme.primary,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
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
            children: [
              for (final (i, loan) in group.loans.indexed) ...[
                if (i > 0) const Divider(height: 1),
                LoanTile(loan: loan),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One loan: what is left, the original amount, how much has come back, and
/// a colored pill with its status.
class LoanTile extends StatelessWidget {
  const LoanTile({super.key, required this.loan});

  final LoanWithPayments loan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final grey = theme.colorScheme.onSurfaceVariant;
    final status = loan.statusOn(DateTime.now());
    final total = loan.loan.amountCents;
    final note = dueNote(loan);
    // For the bar only, so a double is fine here (it is not money).
    final share = total == 0 ? 0.0 : loan.paidCents / total;

    return InkWell(
      // Loans can be opened from Home (/loans) or More (/more/loans), so add
      // the loan's id to whichever address this screen is on.
      onTap: () =>
          context.go('${GoRouterState.of(context).uri.path}/${loan.loan.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Money.format(loan.isPaid ? total : loan.remainingCents),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      // Paid-back loans fade, so the ones to chase stand out.
                      color: loan.isPaid ? grey : null,
                    ),
                  ),
                ),
                Icon(
                  loan.isPaid
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: loan.isPaid ? colors.income : grey,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Lent ${friendlyDate(loan.loan.lentOn)} · '
              'of ${Money.format(total)}',
              style: theme.textTheme.bodySmall?.copyWith(color: grey),
            ),
            if (loan.paidCents > 0 && !loan.isPaid) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                LoanStatusPill(status),
                if (note != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status == LoanStatus.overdue
                            ? colors.expense
                            : grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/screen_padding.dart';
import '../../../core/widgets/skeleton.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../data/loans_provider.dart';
import '../domain/loan.dart';
import '../domain/loan_summary.dart';
import 'loan_form_sheet.dart';
import 'loan_payment_sheet.dart';

/// One loan: how much is left, every repayment, and buttons to record a new
/// one, edit, or delete.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return sure == true;
  }

  void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  Future<void> _deleteLoan(BuildContext context, WidgetRef ref) async {
    final sure = await _confirm(
      context,
      title: 'Delete this loan?',
      message:
          'This removes the loan and all its repayments. Money it took from '
          'or added to your accounts is undone.',
      action: 'Delete',
    );
    if (!sure || !context.mounted) return;
    try {
      await ref.read(loansProvider.notifier).remove(loanId);
      if (context.mounted) context.go('/loans');
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _deletePayment(
    BuildContext context,
    WidgetRef ref,
    LoanPayment payment,
  ) async {
    final sure = await _confirm(
      context,
      title: 'Delete this repayment?',
      message:
          '${Money.format(payment.amountCents)} will be owed again. If it was '
          'added to an account, it is taken back out.',
      action: 'Delete',
    );
    if (!sure || !context.mounted) return;
    try {
      await ref.read(loansProvider.notifier).removePayment(payment.id);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loanByIdProvider(loanId));
    final loan = async.value;

    if (async.hasError && loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: ErrorView(
          error: async.error!,
          title: "Couldn't load this loan",
          onRetry: () => ref.invalidate(loansProvider),
        ),
      );
    }
    if (!async.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const SkeletonPage(cards: 2),
      );
    }
    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan')),
        body: const Center(child: Text('This loan is gone.')),
      );
    }

    final accounts = ref.watch(accountsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.loan.person),
        actions: [
          IconButton(
            tooltip: 'Edit loan',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showLoanFormSheet(context, existing: loan.loan),
          ),
          IconButton(
            tooltip: 'Delete loan',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _deleteLoan(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: screenPadding(context),
        children: [
          _SummaryCard(loan: loan, accounts: accounts),
          if (!loan.isPaid) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => showLoanPaymentSheet(context, loan: loan),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record repayment'),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Repayments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (loan.payments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Nothing paid back yet.')),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final p in loan.payments.reversed)
                    _PaymentTile(
                      payment: p,
                      accounts: accounts,
                      onDelete: () => _deletePayment(context, ref, p),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Still owed" with a progress bar, then the loan's details.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.loan, required this.accounts});

  final LoanWithPayments loan;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final total = loan.loan.amountCents;
    final status = loan.statusOn(DateTime.now());
    // For the bar only, so a double is fine here (it is not money).
    final share = total == 0 ? 0.0 : loan.paidCents / total;
    final note = loan.loan.note;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.isPaid ? 'Paid back in full' : 'Still owed',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.format(loan.isPaid ? total : loan.remainingCents),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: loan.isPaid ? colors.income : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${Money.format(loan.paidCents)} paid back of '
              '${Money.format(total)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              statusLine(loan),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: status == LoanStatus.overdue
                    ? colors.expense
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 28),
            Text(
              'Lent ${fullDate(loan.loan.lentOn)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _accountText(
                loan.loan.accountId,
                accounts,
                withAccount: 'Taken from',
                noAccount: 'No account was changed',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// One repayment: amount, date, where it went, and a delete button.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.accounts,
    required this.onDelete,
  });

  final LoanPayment payment;
  final List<Account> accounts;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = payment.note;

    return ListTile(
      title: Text(
        Money.format(payment.amountCents),
        style: theme.textTheme.titleMedium?.copyWith(
          color: context.appColors.income,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${friendlyDate(payment.paidOn)} · '
        '${_accountText(payment.accountId, accounts, withAccount: 'Added to', noAccount: 'No account changed')}'
        '${note == null ? '' : '\n$note'}',
      ),
      isThreeLine: note != null,
      trailing: IconButton(
        tooltip: 'Delete repayment',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
    );
  }
}

/// "Taken from GoTyme", "Added to Cash", or [noAccount] when no account was
/// touched. An account that is archived (not in [accounts]) shows as such.
String _accountText(
  String? accountId,
  List<Account> accounts, {
  required String withAccount,
  required String noAccount,
}) {
  if (accountId == null) return noAccount;
  final name = accounts.where((a) => a.id == accountId).firstOrNull?.name;
  return '$withAccount ${name ?? 'an archived account'}';
}

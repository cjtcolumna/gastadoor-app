import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_hero_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../data/loans_provider.dart';
import '../domain/loan_summary.dart';
import 'loan_fields.dart';

/// Opens the form to record money paid back on [loan].
Future<void> showLoanPaymentSheet(
  BuildContext context, {
  required LoanWithPayments loan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LoanPaymentSheet(loan: loan),
  );
}

class LoanPaymentSheet extends ConsumerStatefulWidget {
  const LoanPaymentSheet({super.key, required this.loan});

  final LoanWithPayments loan;

  @override
  ConsumerState<LoanPaymentSheet> createState() => _LoanPaymentSheetState();
}

class _LoanPaymentSheetState extends ConsumerState<LoanPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _paidOn = dateOnly(DateTime.now());

  // Does the money go into an account? Yes, unless you turn it off.
  bool _useAccount = true;
  String? _accountId;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The account you picked. Until then: the account the loan was taken
  /// from (money usually goes back where it came from), or else the first
  /// account. An archived account can't be picked, so it is skipped.
  String? get _effectiveAccountId {
    if (_accountId != null) return _accountId;
    final accounts = ref.read(accountsProvider).value ?? const [];
    final lentFrom = widget.loan.loan.accountId;
    if (lentFrom != null && accounts.any((a) => a.id == lentFrom)) {
      return lentFrom;
    }
    return accounts.firstOrNull?.id;
  }

  Future<void> _pickDate() async {
    final picked = await pickLoanDate(
      context,
      initial: _paidOn,
      firstDate: widget.loan.loan.lentOn,
    );
    if (picked != null) setState(() => _paidOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = Money.parseToCents(_amountController.text)!;
    final remaining = widget.loan.remainingCents;

    if (cents > remaining) {
      setState(
        () => _error =
            'That is more than what is still owed '
            '(${Money.format(remaining)}).',
      );
      return;
    }
    final accountId = _useAccount ? _effectiveAccountId : null;
    if (_useAccount && accountId == null) {
      setState(
        () => _error =
            'Pick an account, or turn the switch off to leave accounts alone.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(loansProvider.notifier)
          .addPayment(
            loanId: widget.loan.loan.id,
            amountCents: cents,
            paidOn: _paidOn,
            note: _noteController.text,
            accountId: accountId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  /// "Save repayment", or once there is an amount: "Record ₱1,000.00 from Mark".
  String get _buttonLabel {
    final cents = Money.parseToCents(_amountController.text);
    if (cents == null || cents <= 0) return 'Save repayment';
    return 'Record ${Money.format(cents)} from ${widget.loan.loan.person}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final loan = widget.loan;

    // The fields scroll; the Save button stays pinned below them.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Record repayment', style: theme.textTheme.titleLarge),
                  Text(
                    '${loan.loan.person} still owes '
                    '${Money.format(loan.remainingCents)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Money coming in is green, like income.
                  AmountHeroField(
                    controller: _amountController,
                    color: context.appColors.income,
                    autofocus: true,
                    enabled: !_saving,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => _amountController.text = Money.toInputText(
                              loan.remainingCents,
                            ),
                      child: const Text('Paid in full'),
                    ),
                  ),
                  // Rebuilds as you type, so the balance preview is live.
                  ListenableBuilder(
                    listenable: _amountController,
                    builder: (context, _) => AccountChoice(
                      title: 'Put it in an account',
                      onHelp: 'This amount is added to the account you pick.',
                      offHelp:
                          'No account changes. Use this if the money was '
                          'already counted, or it did not go into any of your '
                          'accounts.',
                      useAccount: _useAccount,
                      accountId: _effectiveAccountId,
                      amountCents: Money.parseToCents(_amountController.text),
                      moneyLeaves: false,
                      enabled: !_saving,
                      onUseAccountChanged: (v) =>
                          setState(() => _useAccount = v),
                      onAccountPicked: (id) => setState(() => _accountId = id),
                    ),
                  ),
                  const LoanSectionLabel('Details'),
                  LoanGroup(
                    children: [
                      LoanDateRow(
                        label: 'Date paid',
                        date: _paidOn,
                        onTap: _saving ? null : _pickDate,
                      ),
                      LoanNoteRow(
                        key: const Key('loan-note'),
                        controller: _noteController,
                        enabled: !_saving,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + keyboard),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              ListenableBuilder(
                listenable: _amountController,
                builder: (context, _) => FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(
                          _buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

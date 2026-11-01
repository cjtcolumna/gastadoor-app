import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
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

  String? get _effectiveAccountId =>
      _accountId ?? ref.read(accountsProvider).value?.firstOrNull?.id;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final loan = widget.loan;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
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
            const SizedBox(height: 20),
            MoneyTextField(
              controller: _amountController,
              label: 'Amount paid back',
              mustBePositive: true,
              enabled: !_saving,
              autofocus: true,
              large: true,
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
            const SizedBox(height: 8),
            LoanDateField(
              label: 'Date paid',
              date: _paidOn,
              onTap: _saving ? null : _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
            ),
            const SizedBox(height: 8),
            AccountChoice(
              title: 'Put it in an account',
              onHelp: 'This amount is added to the account you pick.',
              offHelp:
                  'No account changes. Use this if the money was already '
                  'counted, or it did not go into any of your accounts.',
              useAccount: _useAccount,
              accountId: _effectiveAccountId,
              enabled: !_saving,
              onUseAccountChanged: (v) => setState(() => _useAccount = v),
              onAccountPicked: (id) => setState(() => _accountId = id),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save repayment'),
            ),
          ],
        ),
      ),
    );
  }
}

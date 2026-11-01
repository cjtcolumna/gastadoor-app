import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../data/loans_provider.dart';
import '../domain/loan.dart';
import 'loan_fields.dart';

/// Opens the form to lend money, or to edit [existing] (who, due date, note).
Future<void> showLoanFormSheet(BuildContext context, {Loan? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LoanFormSheet(existing: existing),
  );
}

class LoanFormSheet extends ConsumerStatefulWidget {
  const LoanFormSheet({super.key, this.existing});

  /// The loan being edited, or null for a new one.
  final Loan? existing;

  @override
  ConsumerState<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends ConsumerState<LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _personController = TextEditingController(
    text: widget.existing?.person,
  );
  late final _amountController = TextEditingController();
  late final _noteController = TextEditingController(
    text: widget.existing?.note,
  );
  late DateTime _lentOn = widget.existing?.lentOn ?? dateOnly(DateTime.now());
  late DateTime? _dueOn = widget.existing?.dueOn;

  // Does this loan take money out of an account? Yes, unless you turn it off
  // (for a loan made before you started tracking).
  bool _useAccount = true;
  String? _accountId;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The account that is picked, or the first one until you pick another.
  String? get _effectiveAccountId =>
      _accountId ?? ref.read(accountsProvider).value?.firstOrNull?.id;

  Future<void> _pickLentOn() async {
    final picked = await pickLoanDate(context, initial: _lentOn);
    if (picked != null) setState(() => _lentOn = picked);
  }

  Future<void> _pickDueOn() async {
    final picked = await pickLoanDate(
      context,
      initial: _dueOn ?? _lentOn,
      firstDate: _lentOn,
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final person = _personController.text.trim();
    final note = _noteController.text;
    final due = _dueOn;

    if (due != null && due.isBefore(_lentOn)) {
      setState(() => _error = "The due date can't be before the day you lent.");
      return;
    }
    final accountId = _useAccount ? _effectiveAccountId : null;
    if (!_isEditing && _useAccount && accountId == null) {
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
      final loans = ref.read(loansProvider.notifier);
      final existing = widget.existing;
      if (existing == null) {
        await loans.add(
          person: person,
          amountCents: Money.parseToCents(_amountController.text)!,
          lentOn: _lentOn,
          dueOn: due,
          note: note,
          accountId: accountId,
        );
      } else {
        await loans.saveDetails(
          existing.copyWith(
            person: person,
            dueOn: due,
            note: note.trim().isEmpty ? null : note.trim(),
          ),
        );
      }
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
    final existing = widget.existing;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit loan' : 'Lend money',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _personController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Who borrowed it?',
                hintText: 'e.g. Mark',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 8),
            if (existing == null)
              MoneyTextField(
                controller: _amountController,
                label: 'Amount lent',
                mustBePositive: true,
                enabled: !_saving,
                autofocus: true,
                large: true,
              )
            else
              Text(
                'Amount lent: ${Money.format(existing.amountCents)}  '
                '(to change it, delete the loan and add it again)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            if (existing == null) ...[
              LoanDateField(
                label: 'Date lent',
                date: _lentOn,
                onTap: _saving ? null : _pickLentOn,
              ),
              const SizedBox(height: 16),
            ],
            LoanDateField(
              label: 'Due date (optional)',
              date: _dueOn,
              emptyText: 'No due date',
              onTap: _saving ? null : _pickDueOn,
              onClear: _saving ? null : () => setState(() => _dueOn = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. For his phone repair',
              ),
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
            ),
            if (existing == null) ...[
              const SizedBox(height: 8),
              AccountChoice(
                title: 'Take it from an account',
                onHelp: 'This amount leaves the account you pick.',
                offHelp:
                    'No account changes. Use this for money you lent before '
                    'you started tracking, when your balance already '
                    'left it out.',
                useAccount: _useAccount,
                accountId: _effectiveAccountId,
                enabled: !_saving,
                onUseAccountChanged: (v) => setState(() => _useAccount = v),
                onAccountPicked: (id) => setState(() => _accountId = id),
              ),
            ],
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
                  : Text(_isEditing ? 'Save' : 'Lend'),
            ),
          ],
        ),
      ),
    );
  }
}

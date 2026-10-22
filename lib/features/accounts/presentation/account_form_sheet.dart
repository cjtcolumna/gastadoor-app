import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_type_ui.dart';

/// Opens the add/edit form as a panel that slides up from the bottom.
/// Pass [account] to edit it, or leave it null to add a new one.
Future<void> showAccountFormSheet(BuildContext context, {Account? account}) {
  return showModalBottomSheet<void>(
    context: context,
    // Open above the whole app, so the floating tab bar can't cover the form.
    useRootNavigator: true,
    isScrollControlled: true, // lets the sheet grow above the keyboard
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountFormSheet(account: account),
  );
}

/// The text in the "Archive this account?" dialog.
/// Adds a warning when the balance isn't zero, because archived accounts
/// don't count toward net worth.
String archiveMessage(String name, int balanceCents) {
  const base =
      'It will be hidden from your accounts and from the + form. '
      'Its past transactions stay in History, and you can restore it '
      'any time from the Archived section.';
  if (balanceCents == 0) return base;
  final amount = Money.format(balanceCents.abs());
  final warning = balanceCents > 0
      ? '$name still has $amount. '
      : '$name still owes $amount. ';
  return '$warning'
      'It will no longer count in your net worth.\n\n$base';
}

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.account?.name,
  );
  late final _balanceController = TextEditingController(
    text: widget.account == null
        ? ''
        : Money.toInputText(widget.account!.openingBalanceCents),
  );
  late AccountType _type = widget.account?.type ?? AccountType.cash;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.account != null;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Runs a save/archive action, showing a spinner and any error.
  Future<void> _run(Future<void> Function(AccountsNotifier) action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action(ref.read(accountsProvider.notifier));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Check your internet connection.';
        });
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final cents = Money.parseToCents(_balanceController.text) ?? 0;

    _run((accounts) {
      final existing = widget.account;
      if (existing == null) {
        return accounts.add(
          name: name,
          type: _type,
          openingBalanceCents: cents,
        );
      }
      return accounts.save(
        existing.copyWith(name: name, type: _type, openingBalanceCents: cents),
      );
    });
  }

  /// Asks first, and warns if the account still has money in it (or owes).
  Future<void> _archive() async {
    final account = widget.account!;
    final balances = ref.read(accountBalancesProvider).value ?? const {};
    final balance = balanceOf(account, balances);

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${account.name}?'),
        content: Text(archiveMessage(account.name, balance)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _run((accounts) => accounts.archive(account.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Push the form up when the on-screen keyboard opens.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // Scrollable, so every field stays reachable on small screens
    // or when the keyboard takes up half the screen.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit account' : 'New account',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. GCash, BDO Savings',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 8),
            _TypePicker(
              selected: _type,
              onChanged: _saving ? null : (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 20),
            MoneyTextField(
              controller: _balanceController,
              label: 'Starting balance',
              helperText:
                  'Use a minus sign for money you owe, like a card bill',
              allowNegative: true,
              required: false,
              enabled: !_saving,
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
                  : Text(_isEditing ? 'Save' : 'Add account'),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _saving ? null : _archive,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Archive account'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of chips, one per account type.
class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.selected, required this.onChanged});

  final AccountType selected;
  final ValueChanged<AccountType>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in AccountType.values)
          ChoiceChip(
            avatar: Icon(type.icon, size: 18),
            label: Text(type.label),
            selected: type == selected,
            onSelected: onChanged == null ? null : (_) => onChanged!(type),
          ),
      ],
    );
  }
}

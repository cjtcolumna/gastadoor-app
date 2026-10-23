import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/account_groups.dart';
import '../domain/balances.dart';
import 'account_type_ui.dart';

/// Opens the add/edit form as a panel that slides up from the bottom.
/// Pass [account] to edit it, or leave it null to add a new one.
/// Pass [parent] to add a new sub-account inside that account.
Future<void> showAccountFormSheet(
  BuildContext context, {
  Account? account,
  Account? parent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Open above the whole app, so the floating tab bar can't cover the form.
    useRootNavigator: true,
    isScrollControlled: true, // lets the sheet grow above the keyboard
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AccountFormSheet(account: account, parent: parent),
  );
}

/// The text in the "Archive this account?" dialog.
/// Adds a warning when the balance isn't zero, because archived accounts
/// don't count toward net worth. [pockets] is how many sub-accounts get
/// archived along with it.
String archiveMessage(String name, int balanceCents, {int pockets = 0}) {
  final base =
      'It will be hidden from your accounts and from the + form. '
      'Its past transactions stay in History, and you can restore it '
      'any time from the Archived section.';
  final withPockets = switch (pockets) {
    0 => base,
    1 => 'Its sub-account will be archived too. $base',
    _ => 'Its $pockets sub-accounts will be archived too. $base',
  };
  if (balanceCents == 0) return withPockets;
  final amount = Money.format(balanceCents.abs());
  final warning = balanceCents > 0
      ? '$name still has $amount. '
      : '$name still owes $amount. ';
  return '$warning'
      'It will no longer count in your net worth.\n\n$withPockets';
}

class AccountFormSheet extends ConsumerStatefulWidget {
  const AccountFormSheet({super.key, this.account, this.parent});

  final Account? account;

  /// For a new sub-account: the account it goes inside.
  final Account? parent;

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
  late AccountType _type =
      widget.account?.type ?? widget.parent?.type ?? AccountType.cash;

  /// The account this one sits inside, or null for a main account.
  late String? _parentId = widget.account?.parentId ?? widget.parent?.id;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _save(Account? parent) {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final cents = Money.parseToCents(_balanceController.text) ?? 0;
    // A pocket always has its parent's type.
    final type = parent?.type ?? _type;

    _run((accounts) {
      final existing = widget.account;
      if (existing == null) {
        return accounts.add(
          name: name,
          type: type,
          openingBalanceCents: cents,
          parentId: parent?.id,
        );
      }
      return accounts.save(
        existing.copyWith(
          name: name,
          type: type,
          openingBalanceCents: cents,
          parentId: parent?.id,
        ),
      );
    });
  }

  /// Asks first, and warns if the account still has money in it (or owes).
  Future<void> _archive() async {
    final account = widget.account!;
    final active = ref.read(accountsProvider).value ?? const <Account>[];
    final balances = ref.read(accountBalancesProvider).value ?? const {};
    final pockets = active.where((a) => a.parentId == account.id).toList();
    // A parent's warning uses the total, since its pockets go too.
    final balance = netWorthCents([account, ...pockets], balances);

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${account.name}?'),
        content: Text(
          archiveMessage(account.name, balance, pockets: pockets.length),
        ),
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

  /// Closes this form and opens a new one for a pocket inside this account.
  void _addPocket() {
    final account = widget.account!;
    final navigator = Navigator.of(context);
    navigator.pop();
    showAccountFormSheet(navigator.context, parent: account);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Push the form up when the on-screen keyboard opens.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final active = ref.watch(accountsProvider).value ?? const <Account>[];
    final options = parentOptions(widget.account, active);
    final parent = options.where((a) => a.id == _parentId).firstOrNull;
    final isPocket = parent != null;
    final title = switch ((_isEditing, isPocket)) {
      (true, true) => 'Edit sub-account',
      (true, false) => 'Edit account',
      (false, true) => 'New sub-account',
      (false, false) => 'New account',
    };

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
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: isPocket
                    ? 'e.g. Travel, Emergency Fund'
                    : 'e.g. GCash, BDO Savings',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ParentPicker(
                options: options,
                selectedId: parent?.id,
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _parentId = id),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),
            if (isPocket)
              // Pockets share their parent's type, so no picker.
              _SameTypeNote(parent: parent)
            else
              _TypePicker(
                selected: _type,
                onChanged: _saving ? null : (t) => setState(() => _type = t),
              ),
            const SizedBox(height: 20),
            MoneyTextField(
              controller: _balanceController,
              label: 'Starting balance',
              helperText: isPocket
                  ? 'Money already set aside in this pocket'
                  : 'Use a minus sign for money you owe, like a card bill',
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
              onPressed: _saving ? null : () => _save(parent),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _isEditing
                          ? 'Save'
                          : isPocket
                          ? 'Add sub-account'
                          : 'Add account',
                    ),
            ),
            // Only main accounts can hold pockets (one level only).
            if (_isEditing && widget.account!.parentId == null)
              TextButton.icon(
                onPressed: _saving ? null : _addPocket,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a sub-account'),
              ),
            if (_isEditing)
              TextButton(
                onPressed: _saving ? null : _archive,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(
                  isPocket ? 'Archive sub-account' : 'Archive account',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Inside account": None (a main account), or one of the main accounts.
class _ParentPicker extends StatelessWidget {
  const _ParentPicker({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Account> options;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      // A new key when the choice changes from outside, so it redraws.
      key: ValueKey(selectedId),
      initialValue: selectedId,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded),
      decoration: const InputDecoration(
        labelText: 'Inside account (optional)',
        helperText: 'Make this a pocket, like Travel inside GoTyme',
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('None (main account)')),
        for (final a in options)
          DropdownMenuItem(
            value: a.id,
            child: Row(
              children: [
                Icon(a.type.icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Shown instead of the type chips for a pocket: "Bank, same as GoTyme".
class _SameTypeNote extends StatelessWidget {
  const _SameTypeNote({required this.parent});

  final Account parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          parent.type.icon,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${parent.type.label}, same as ${parent.name}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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

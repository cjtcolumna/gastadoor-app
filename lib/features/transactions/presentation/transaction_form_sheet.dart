import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_type_ui.dart';
import '../../accounts/presentation/pocket_visuals.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_form_sheet.dart';
import '../../categories/presentation/category_visuals.dart';
import '../data/transaction_actions.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';

/// Opens the add/edit form for an expense, income, or transfer.
/// Pass [existing] to edit it, or leave it null to add a new one.
/// For a new one, [kind], [accountId] and [toAccountId] pre-fill the form
/// (used by "Add money" on a sub-account: a transfer GoTyme -> Travel).
Future<void> showTransactionFormSheet(
  BuildContext context, {
  Transaction? existing,
  TransactionKind? kind,
  String? accountId,
  String? toAccountId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionFormSheet(
      existing: existing,
      initialKind: kind,
      initialAccountId: accountId,
      initialToAccountId: toAccountId,
    ),
  );
}

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.existing,
    this.initialKind,
    this.initialAccountId,
    this.initialToAccountId,
  });

  final Transaction? existing;

  /// Starting choices for a new transaction (ignored when editing).
  final TransactionKind? initialKind;
  final String? initialAccountId;
  final String? initialToAccountId;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.toInputText(widget.existing!.amountCents),
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note,
  );
  late TransactionKind _kind =
      widget.existing?.kind ?? widget.initialKind ?? TransactionKind.expense;
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId =
      widget.existing?.accountId ?? widget.initialAccountId;
  late String? _toAccountId =
      widget.existing?.toAccountId ?? widget.initialToAccountId;
  late DateTime _date = dateOnly(widget.existing?.occurredOn ?? DateTime.now());
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _isTransfer => _kind == TransactionKind.transfer;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// If this transaction belongs to an account that's now archived,
  /// returns that account so the form can still show it. Otherwise null.
  Account? _archivedOriginal(List<Account> active) {
    final originalId = widget.existing?.accountId;
    if (originalId == null || active.any((a) => a.id == originalId)) {
      return null;
    }
    final archived = ref.watch(archivedAccountsProvider).value ?? const [];
    return archived.where((a) => a.id == originalId).firstOrNull;
  }

  void _changeKind(TransactionKind kind) {
    setState(() {
      _kind = kind;
      // Expense categories don't fit income (and transfers have none).
      _categoryId = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Calendar only: hides the pencil "type a date" button.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save(String? accountId, String? toAccountId) async {
    if (!_formKey.currentState!.validate()) return;
    if (accountId == null) {
      setState(() => _error = 'Add an account first (Accounts tab).');
      return;
    }
    if (_isTransfer && toAccountId == null) {
      setState(
        () => _error =
            'A transfer needs two accounts. Add another in the Accounts tab.',
      );
      return;
    }
    final draft = TransactionDraft(
      kind: _kind,
      amountCents: Money.parseToCents(_amountController.text)!,
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: _categoryId,
      occurredOn: _date,
      note: _noteController.text,
    );
    final actions = ref.read(transactionActionsProvider);
    await _run(
      () => _isEditing
          ? actions.update(widget.existing!.id, draft)
          : actions.add(draft),
    );
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _run(
      () => ref.read(transactionActionsProvider).delete(widget.existing!.id),
    );
  }

  /// Shows a spinner while [action] runs, then closes the sheet,
  /// or shows an error if it failed.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
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
    // Each main account followed by its pockets (GoTyme, Travel, ...).
    final accounts = inGroupOrder(
      ref.watch(accountsProvider).value ?? const <Account>[],
    );
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.kind == _kind)
        .toList();
    // Until the user picks one, use their first account (usually Cash).
    final accountId = _accountId ?? accounts.firstOrNull?.id;
    // Transfers: "To" can't be the same as "From". If nothing valid is
    // picked yet, use the first other account.
    final toAccountId = (_toAccountId != null && _toAccountId != accountId)
        ? _toAccountId
        : accounts.where((a) => a.id != accountId).firstOrNull?.id;
    final kindWord = _kind.name; // 'expense', 'income', or 'transfer'

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit $kindWord' : 'New $kindWord',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _KindSwitch(kind: _kind, onChanged: _saving ? null : _changeKind),
            const SizedBox(height: 16),
            MoneyTextField(
              controller: _amountController,
              mustBePositive: true,
              autofocus: !_isEditing,
              large: true,
              enabled: !_saving,
            ),
            if (_isTransfer) ...[
              // Transfers: where the money leaves, and where it arrives.
              const _SectionLabel('From'),
              _AccountPicker(
                accounts: accounts,
                archivedAccount: _archivedOriginal(accounts),
                selectedId: accountId,
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _accountId = id),
              ),
              const _SectionLabel('To'),
              _AccountPicker(
                // You can't transfer into the same account.
                accounts: accounts.where((a) => a.id != accountId).toList(),
                allAccounts: accounts,
                selectedId: toAccountId,
                emptyText: 'Add a second account to make transfers.',
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _toAccountId = id),
              ),
            ] else ...[
              const _SectionLabel('Category'),
              _CategoryPicker(
                categories: categories,
                selectedId: _categoryId,
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _categoryId = id),
                // Quick add: opens the category form on top of this one.
                onAddNew: _saving
                    ? null
                    : () => showCategoryFormSheet(context, kind: _kind),
              ),
              const _SectionLabel('Account'),
              _AccountPicker(
                accounts: accounts,
                archivedAccount: _archivedOriginal(accounts),
                selectedId: accountId,
                onChanged: _saving
                    ? null
                    : (id) => setState(() => _accountId = id),
              ),
            ],
            const _SectionLabel('Date'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text(friendlyDate(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Jollibee with friends',
              ),
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving ? null : () => _save(accountId, toAccountId),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save'),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text('Delete $kindWord'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Expense | Income | Transfer toggle.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});

  final TransactionKind kind;
  final ValueChanged<TransactionKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final money = context.appColors;
    // Red for expense, green for income, blue for transfer.
    final (color, soft) = switch (kind) {
      TransactionKind.expense => (money.expense, money.expenseSoft),
      TransactionKind.income => (money.income, money.incomeSoft),
      TransactionKind.transfer => (money.transfer, money.transferSoft),
    };

    return SegmentedButton<TransactionKind>(
      segments: const [
        ButtonSegment(
          value: TransactionKind.expense,
          label: Text('Expense'),
          // Same icons as Home and History: ↗ out, ↙ in, ⇄ between.
          icon: Icon(Icons.north_east_rounded),
        ),
        ButtonSegment(
          value: TransactionKind.income,
          label: Text('Income'),
          icon: Icon(Icons.south_west_rounded),
        ),
        ButtonSegment(
          value: TransactionKind.transfer,
          label: Text('Transfer'),
          icon: Icon(Icons.swap_horiz_rounded),
        ),
      ],
      selected: {kind},
      // Keep each side's own icon when selected (no check mark swap).
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: soft,
        selectedForegroundColor: color,
        // Three tabs on a phone: keep them snug so the words fit.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Category chips. Tapping the selected chip again clears it.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
    this.onAddNew,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  /// Tapped "+ New": add a category without leaving the form.
  final VoidCallback? onAddNew;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          ChoiceChip(
            avatar: Icon(
              categoryIconFor(category.icon),
              color: categoryColorFor(category.color, colors),
            ),
            // Keep the icon visible when selected (no check mark over it),
            // and tint the chip with the category's own color.
            showCheckmark: false,
            selectedColor: categoryColorFor(
              category.color,
              colors,
            ).withValues(alpha: 0.16),
            label: Text(category.name),
            selected: category.id == selectedId,
            onSelected: onChanged == null
                ? null
                : (on) => onChanged!(on ? category.id : null),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded),
          label: const Text('New'),
          tooltip: 'New category',
          onPressed: onAddNew,
        ),
      ],
    );
  }
}

/// Account chips (Cash, GCash, BDO...). One is always selected.
class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.archivedAccount,
    this.allAccounts,
    this.emptyText = 'No accounts yet. Add one in the Accounts tab.',
  });

  final List<Account> accounts;

  /// Every account, used to name pockets "GoTyme › Travel" even when the
  /// parent isn't one of the choices. Defaults to [accounts].
  final List<Account>? allAccounts;
  final String? selectedId;
  final ValueChanged<String>? onChanged;

  /// When editing an old transaction from an archived account, that account,
  /// shown as a greyed-out chip so you can see where the money came from.
  final Account? archivedAccount;

  /// What to say when there are no accounts to pick.
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final archived = archivedAccount;
    if (accounts.isEmpty && archived == null) {
      return Text(emptyText);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (archived != null)
          ChoiceChip(
            avatar: Icon(archived.type.icon, size: 18),
            label: Text('${archived.name} (archived)'),
            selected: archived.id == selectedId,
            onSelected: null, // can't pick it for new money, only keep it
          ),
        for (final account in accounts)
          ChoiceChip(
            avatar: Icon(accountIconFor(account), size: 18),
            label: Text(accountLabel(account, allAccounts ?? accounts)),
            selected: account.id == selectedId,
            onSelected: onChanged == null
                ? null
                : (_) => onChanged!(account.id),
          ),
      ],
    );
  }
}

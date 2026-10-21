import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/account_type_ui.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../data/transaction_actions.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';

/// Opens the add/edit form for an expense or income.
/// Pass [existing] to edit it, or leave it null to add a new one.
Future<void> showTransactionFormSheet(
  BuildContext context, {
  Transaction? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TransactionFormSheet(existing: existing),
  );
}

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.existing});

  final Transaction? existing;

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
  late TransactionKind _kind = widget.existing?.kind ?? TransactionKind.expense;
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  late DateTime _date = dateOnly(widget.existing?.occurredOn ?? DateTime.now());
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _changeKind(TransactionKind kind) {
    setState(() {
      _kind = kind;
      _categoryId = null; // expense categories don't fit income, and back
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save(String? accountId) async {
    if (!_formKey.currentState!.validate()) return;
    if (accountId == null) {
      setState(() => _error = 'Add an account first (Accounts tab).');
      return;
    }
    final draft = TransactionDraft(
      kind: _kind,
      amountCents: Money.parseToCents(_amountController.text)!,
      accountId: accountId,
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Check your internet connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.kind == _kind)
        .toList();
    // Until the user picks one, use their first account (usually Cash).
    final accountId = _accountId ?? accounts.firstOrNull?.id;
    final kindWord = _kind == TransactionKind.expense ? 'expense' : 'income';

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
            const _SectionLabel('Category'),
            _CategoryPicker(
              categories: categories,
              selectedId: _categoryId,
              onChanged: _saving
                  ? null
                  : (id) => setState(() => _categoryId = id),
            ),
            const _SectionLabel('Account'),
            _AccountPicker(
              accounts: accounts,
              selectedId: accountId,
              onChanged: _saving
                  ? null
                  : (id) => setState(() => _accountId = id),
            ),
            const _SectionLabel('Date'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
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
              onPressed: _saving ? null : () => _save(accountId),
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

/// Expense | Income toggle.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});

  final TransactionKind kind;
  final ValueChanged<TransactionKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionKind>(
      segments: const [
        ButtonSegment(
          value: TransactionKind.expense,
          label: Text('Expense'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: TransactionKind.income,
          label: Text('Income'),
          icon: Icon(Icons.arrow_downward),
        ),
      ],
      selected: {kind},
      // Red when recording an expense, green for income.
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: kind == TransactionKind.expense
            ? context.appColors.expenseSoft
            : context.appColors.incomeSoft,
        selectedForegroundColor: kind == TransactionKind.expense
            ? context.appColors.expense
            : context.appColors.income,
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
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (categories.isEmpty) {
      return const Text('Loading categories…');
    }
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
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text('No accounts yet. Add one in the Accounts tab.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final account in accounts)
          ChoiceChip(
            avatar: Icon(account.type.icon, size: 18),
            label: Text(account.name),
            selected: account.id == selectedId,
            onSelected: onChanged == null
                ? null
                : (_) => onChanged!(account.id),
          ),
      ],
    );
  }
}

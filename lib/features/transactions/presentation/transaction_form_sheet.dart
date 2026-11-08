import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_hero_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_picker_cards.dart';
import '../../categories/data/categories_repository.dart';
import '../../budgets/data/budgets_provider.dart';
import '../../budgets/domain/budget_progress.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_form_sheet.dart';
import '../../categories/presentation/category_pill.dart';
import '../data/transaction_actions.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction.dart';
import '../domain/transaction_draft.dart';
import 'kind_switch.dart';

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

  /// False until the user picks (or clears) a category. Until then a new
  /// transaction starts on the category used last time for this kind.
  /// Editing counts as picked, so an old transaction keeps what it had.
  late bool _categoryPicked = widget.existing != null;
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
      // Expense categories don't fit income (and transfers have none), so
      // start again from the last category used for the new kind.
      _categoryId = null;
      _categoryPicked = false;
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

  Future<void> _save(
    String? accountId,
    String? toAccountId,
    String? categoryId,
  ) async {
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
      categoryId: _isTransfer ? null : categoryId,
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
    // Until the user picks one, use the account they used last time
    // (or their first account if that one is missing).
    final accountId =
        _accountId ??
        defaultAccountId(accounts, ref.watch(lastUsedAccountIdProvider).value);
    // Transfers: "To" can't be the same as "From". If nothing valid is
    // picked yet, use the first other account.
    final toAccountId = (_toAccountId != null && _toAccountId != accountId)
        ? _toAccountId
        : accounts.where((a) => a.id != accountId).firstOrNull?.id;
    // Each account's balance, shown small under its name in the pickers.
    final balances = ref.watch(accountBalancesProvider).value;
    final kindWord = _kind.name; // 'expense', 'income', or 'transfer'
    // The picked category, or (until the user picks) the one used last
    // time for this kind, as long as it still exists.
    final lastCategoryId = _isTransfer
        ? null
        : ref.watch(lastCategoryIdProvider(_kind)).value;
    final categoryId = _categoryPicked
        ? _categoryId
        : (categories.any((c) => c.id == lastCategoryId)
              ? lastCategoryId
              : null);

    // This month's limit for each category (shown small inside its pill).
    final budgetByCategory = <String, BudgetProgress>{
      for (final p
          in ref.watch(budgetProgressProvider).value ??
              const <BudgetProgress>[])
        p.category.id: p,
    };

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
                  Text(
                    _isEditing ? 'Edit $kindWord' : 'New $kindWord',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  KindSwitch(
                    kind: _kind,
                    onChanged: _saving ? null : _changeKind,
                  ),
                  const SizedBox(height: 16),
                  AmountHeroField(
                    controller: _amountController,
                    // Red for expense, green for income, blue for transfer
                    // (the same colors as the switch above).
                    color: switch (_kind) {
                      TransactionKind.expense => context.appColors.expense,
                      TransactionKind.income => context.appColors.income,
                      TransactionKind.transfer => context.appColors.transfer,
                    },
                    autofocus: !_isEditing,
                    enabled: !_saving,
                  ),
                  const _SectionLabel('Notes'),
                  TextFormField(
                    controller: _noteController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      hintText: switch (_kind) {
                        TransactionKind.expense => 'What was this for?',
                        TransactionKind.income => 'Where did this come from?',
                        TransactionKind.transfer => 'Why are you moving this?',
                      },
                      // Hide the "0/500" counter; the limit still applies.
                      counterText: '',
                    ),
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (_isTransfer) ...[
                    // Transfers: where the money leaves, and where it arrives.
                    const _SectionLabel('From'),
                    AccountPickerCards(
                      balances: balances,
                      accounts: accounts,
                      archivedAccount: _archivedOriginal(accounts),
                      selectedId: accountId,
                      onChanged: _saving
                          ? null
                          : (id) => setState(() => _accountId = id),
                    ),
                    const _SectionLabel('To'),
                    AccountPickerCards(
                      balances: balances,
                      accounts: accounts,
                      // You can't transfer into the same account.
                      disabledId: accountId,
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
                      budgets: budgetByCategory,
                      selectedId: categoryId,
                      onChanged: _saving
                          ? null
                          : (id) => setState(() {
                              _categoryId = id;
                              _categoryPicked = true;
                            }),
                      // Quick add: opens the category form on top of this one.
                      onAddNew: _saving
                          ? null
                          : () => showCategoryFormSheet(context, kind: _kind),
                    ),
                    const _SectionLabel('Account'),
                    AccountPickerCards(
                      balances: balances,
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
                      label: Text(fullDate(_date)),
                    ),
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
              FilledButton(
                onPressed: _saving
                    ? null
                    : () => _save(accountId, toAccountId, categoryId),
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
      ],
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

/// Category pills (same height, width fits the content), ending with a
/// "+ New" pill. Tapping the selected pill again clears it.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.budgets,
    required this.selectedId,
    required this.onChanged,
    this.onAddNew,
  });

  final List<Category> categories;

  /// Each category's budget for this month (a category may have none).
  final Map<String, BudgetProgress> budgets;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  /// Tapped "+ New": add a category without leaving the form.
  final VoidCallback? onAddNew;

  @override
  Widget build(BuildContext context) {
    // Each pill is as wide as its content; all have the same height.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          CategoryPill(
            category: category,
            budget: budgets[category.id],
            selected: category.id == selectedId,
            onTap: onChanged == null
                ? null
                : () => onChanged!(
                    category.id == selectedId ? null : category.id,
                  ),
          ),
        // "+ New" is a pill too, at the end of the categories.
        NewCategoryPill(onTap: onAddNew),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/friendly_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_visuals.dart';
import '../../transactions/domain/transaction.dart';
import '../data/budgets_provider.dart';
import '../domain/budget.dart';

/// Opens the add/edit budget form. Pass [existing] to edit it.
Future<void> showBudgetFormSheet(BuildContext context, {Budget? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BudgetFormSheet(existing: existing),
  );
}

/// The text saved as a budget's name: the category's name, or
/// "All spending" when the budget covers every expense.
String budgetName(Category? category) => category?.name ?? 'All spending';

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({super.key, this.existing});

  final Budget? existing;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.toInputText(widget.existing!.amountCents),
  );

  /// null = "All spending". Only meaningful once [_picked] is true.
  late String? _categoryId = widget.existing?.categoryId;

  /// When adding, nothing is chosen until the user taps a chip.
  late bool _picked = widget.existing != null;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save(List<Category> categories) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_picked) {
      setState(() => _error = 'Choose what this budget is for.');
      return;
    }
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    final cents = Money.parseToCents(_amountController.text)!;
    final budgets = ref.read(budgetsProvider.notifier);
    final existing = widget.existing;

    await _run(
      () => existing == null
          ? budgets.add(
              categoryId: _categoryId,
              name: budgetName(category),
              amountCents: cents,
            )
          : budgets.save(
              existing.copyWith(
                categoryId: _categoryId,
                name: budgetName(category),
                amountCents: cents,
              ),
            ),
    );
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this budget?'),
        content: const Text(
          'Your expenses stay as they are. Only the limit is removed.',
        ),
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
      () => ref.read(budgetsProvider.notifier).remove(widget.existing!.id),
    );
  }

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
    final expenseCategories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.kind == TransactionKind.expense)
        .toList();
    final budgets = ref.watch(budgetsProvider).value ?? const <Budget>[];

    // Hide targets that already have a budget (except this one, when editing),
    // so you can't make two "Food" budgets.
    final taken = {
      for (final b in budgets)
        if (b.id != widget.existing?.id) b.categoryId,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit budget' : 'New monthly budget',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            MoneyTextField(
              controller: _amountController,
              label: 'Monthly limit',
              mustBePositive: true,
              autofocus: !_isEditing,
              large: true,
              enabled: !_saving,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                'For',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _TargetPicker(
              categories: expenseCategories,
              taken: taken,
              selected: _picked ? _categoryId : _notPicked,
              onChanged: _saving
                  ? null
                  : (id) => setState(() {
                      _picked = true;
                      _categoryId = id;
                    }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.appColors.expense)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : () => _save(expenseCategories),
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
                  foregroundColor: context.appColors.expense,
                ),
                child: const Text('Delete budget'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A value no real category id can have, meaning "nothing chosen yet".
const _notPicked = '__none__';

/// "All spending" plus one chip per expense category.
class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.categories,
    required this.taken,
    required this.selected,
    required this.onChanged,
  });

  final List<Category> categories;

  /// Category ids (and null for "All spending") that already have a budget.
  final Set<String?> taken;
  final String? selected;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!taken.contains(null))
          ChoiceChip(
            avatar: Icon(
              Icons.account_balance_wallet_rounded,
              color: colors.primary,
            ),
            label: const Text('All spending'),
            selected: selected == null,
            onSelected: onChanged == null ? null : (_) => onChanged!(null),
          ),
        for (final c in categories)
          if (!taken.contains(c.id))
            ChoiceChip(
              avatar: Icon(
                categoryIconFor(c.icon),
                color: categoryColorFor(c.color, colors),
              ),
              label: Text(c.name),
              selected: selected == c.id,
              selectedColor: categoryColorFor(
                c.color,
                colors,
              ).withValues(alpha: 0.16),
              onSelected: onChanged == null ? null : (_) => onChanged!(c.id),
            ),
      ],
    );
  }
}

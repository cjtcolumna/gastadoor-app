import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../transactions/domain/transaction.dart';
import '../data/categories_repository.dart';
import '../domain/category.dart';
import 'category_visuals.dart';

/// Opens the add/edit category form. Pass [existing] to edit it.
/// When adding, [kind] picks whether it starts as Expense or Income.
Future<void> showCategoryFormSheet(
  BuildContext context, {
  Category? existing,
  TransactionKind kind = TransactionKind.expense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar (and above other sheets)
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CategoryFormSheet(existing: existing, initialKind: kind),
  );
}

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({
    super.key,
    this.existing,
    this.initialKind = TransactionKind.expense,
  });

  final Category? existing;
  final TransactionKind initialKind;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late TransactionKind _kind = widget.existing?.kind ?? widget.initialKind;
  late String _icon = _known(widget.existing?.icon, categoryIcons, 'category');
  late String _color = _known(widget.existing?.color, categoryColors, 'blue');
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  /// Keeps a saved name if the app knows it (old emojis aren't), else [fallback].
  static String _known(
    String? saved,
    Map<String, Object> options,
    String fallback,
  ) => saved != null && options.containsKey(saved) ? saved : fallback;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final actions = ref.read(categoryActionsProvider);
    final name = _nameController.text.trim();
    final existing = widget.existing;
    await _run(
      () => existing == null
          ? actions.add(name: name, kind: _kind, icon: _icon, color: _color)
          : actions.save(
              existing.copyWith(name: name, icon: _icon, color: _color),
            ),
      name,
    );
  }

  Future<void> _archive() async {
    final category = widget.existing!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${category.name}?'),
        content: const Text(
          'It will be hidden when you add expenses or budgets. '
          'Past transactions keep it, and you can restore it any time '
          'from the Archived section.',
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
    await _run(
      () => ref.read(categoryActionsProvider).archive(category.id),
      category.name,
    );
  }

  Future<void> _run(Future<void> Function() action, String name) async {
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
          _error = categorySaveError(e, name);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final kindWord = _kind == TransactionKind.income ? 'income' : 'expense';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Live preview of how the category will look.
                CategoryAvatar(icon: _icon, color: _color, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit category' : 'New $kindWord category',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              autofocus: !_isEditing,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Coffee, Rent, Freelance',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            // Kind can only be chosen when adding, so old expenses never end
            // up in an income category.
            if (!_isEditing) ...[
              SegmentedButton<TransactionKind>(
                segments: const [
                  ButtonSegment(
                    value: TransactionKind.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionKind.income,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west_rounded),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _kind = s.first),
              ),
            ],
            const _Label('Icon'),
            _IconGrid(
              selected: _icon,
              color: categoryColorFor(_color, theme.colorScheme),
              onChanged: _saving ? null : (i) => setState(() => _icon = i),
            ),
            const _Label('Color'),
            _ColorRow(
              selected: _color,
              onChanged: _saving ? null : (c) => setState(() => _color = c),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: context.appColors.expense)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save'),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _saving ? null : _archive,
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.expense,
                ),
                child: const Text('Archive category'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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

/// Every icon from the lookup table, as tappable circles.
class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selected,
    required this.color,
    required this.onChanged,
  });

  final String selected;
  final Color color;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final MapEntry(key: name, value: icon) in categoryIcons.entries)
          Semantics(
            label: name,
            selected: name == selected,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onChanged == null ? null : () => onChanged!(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: name == selected
                      ? color.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: name == selected ? color : context.appColors.border,
                    width: name == selected ? 2 : 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: name == selected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Every color from the palette, as tappable dots.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final MapEntry(key: name, value: color) in categoryColors.entries)
          Semantics(
            label: name,
            selected: name == selected,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onChanged == null ? null : () => onChanged!(name),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  // A white gap and a ring show the chosen color.
                  border: Border.all(
                    color: name == selected ? Colors.white : color,
                    width: 3,
                  ),
                  boxShadow: name == selected
                      ? [BoxShadow(color: color, spreadRadius: 2)]
                      : null,
                ),
                child: name == selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

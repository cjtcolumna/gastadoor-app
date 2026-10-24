import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_text_field.dart';
import '../data/accounts_provider.dart';
import '../domain/account.dart';
import '../domain/balances.dart';
import 'account_form_sheet.dart' show archiveMessage;
import 'pocket_visuals.dart';

/// Opens the form to add a sub-account inside [parent], or to edit
/// [pocket] when it's given.
Future<void> showPocketFormSheet(
  BuildContext context, {
  required Account parent,
  Account? pocket,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PocketFormSheet(parent: parent, pocket: pocket),
  );
}

class PocketFormSheet extends ConsumerStatefulWidget {
  const PocketFormSheet({super.key, required this.parent, this.pocket});

  /// The main account this sub-account sits inside.
  final Account parent;

  /// The sub-account being edited, or null for a new one.
  final Account? pocket;

  @override
  ConsumerState<PocketFormSheet> createState() => _PocketFormSheetState();
}

class _PocketFormSheetState extends ConsumerState<PocketFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.pocket?.name);
  late final _goalController = TextEditingController(
    text: widget.pocket?.goalCents == null
        ? ''
        : Money.toInputText(widget.pocket!.goalCents!),
  );
  late final _balanceController = TextEditingController(
    text: widget.pocket == null
        ? ''
        : Money.toInputText(widget.pocket!.openingBalanceCents),
  );
  late String _icon = widget.pocket?.icon ?? 'savings';
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.pocket != null;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final opening = Money.parseToCents(_balanceController.text) ?? 0;
    // An empty goal box means "no goal".
    final goal = Money.parseToCents(_goalController.text);
    final parent = widget.parent;

    _run((accounts) {
      final existing = widget.pocket;
      if (existing == null) {
        return accounts.add(
          name: name,
          type: parent.type, // pockets match their main account
          openingBalanceCents: opening,
          parentId: parent.id,
          icon: _icon,
          goalCents: goal,
        );
      }
      return accounts.save(
        existing.copyWith(
          name: name,
          type: parent.type,
          openingBalanceCents: opening,
          icon: _icon,
          goalCents: goal,
        ),
      );
    });
  }

  Future<void> _archive() async {
    final pocket = widget.pocket!;
    final balances = ref.read(accountBalancesProvider).value ?? const {};
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${pocket.name}?'),
        content: Text(archiveMessage(pocket.name, balanceOf(pocket, balances))),
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
    await _run((accounts) => accounts.archive(pocket.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + keyboard),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit sub-account' : 'New sub-account',
              style: theme.textTheme.titleLarge,
            ),
            Text(
              'Inside ${widget.parent.name}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Travel, Emergency Fund',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Icon',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _IconPicker(
              selected: _icon,
              onChanged: _saving ? null : (i) => setState(() => _icon = i),
            ),
            const SizedBox(height: 20),
            MoneyTextField(
              controller: _goalController,
              label: 'Goal (optional)',
              helperText: 'How much you want to save. Leave empty for none.',
              required: false,
              mustBePositive: true,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),
            MoneyTextField(
              controller: _balanceController,
              label: 'Starting balance',
              helperText: 'Money already set aside in this sub-account',
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
                  : Text(_isEditing ? 'Save' : 'Add sub-account'),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _saving ? null : _archive,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Archive sub-account'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A grid of round icon buttons. The picked one is filled green.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    final soft = context.appColors.incomeSoft;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final MapEntry(key: name, value: icon) in pocketIcons.entries)
          Semantics(
            button: true,
            selected: name == selected,
            label: '$name icon',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onChanged == null ? null : () => onChanged!(name),
              radius: 26,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: name == selected ? green : soft,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: name == selected ? Colors.white : green,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

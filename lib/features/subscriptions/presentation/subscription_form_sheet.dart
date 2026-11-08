import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/amount_hero_field.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_picker_cards.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/presentation/category_form_sheet.dart';
import '../../categories/presentation/category_pill.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/subscriptions_provider.dart';
import '../domain/subscription.dart';
import '../domain/subscription_totals.dart';

/// Opens the form to add a subscription, or to edit [existing] (including
/// pausing or deleting it).
Future<void> showSubscriptionFormSheet(
  BuildContext context, {
  Subscription? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SubscriptionFormSheet(existing: existing),
  );
}

class SubscriptionFormSheet extends ConsumerStatefulWidget {
  const SubscriptionFormSheet({super.key, this.existing});

  /// The subscription being edited, or null for a new one.
  final Subscription? existing;

  @override
  ConsumerState<SubscriptionFormSheet> createState() =>
      _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends ConsumerState<SubscriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : Money.toInputText(widget.existing!.amountCents),
  );
  late SubscriptionFrequency _frequency =
      widget.existing?.frequency ?? SubscriptionFrequency.monthly;

  /// The "Next charge" date. A new subscription starts on today.
  late DateTime _date = dateOnly(
    widget.existing?.nextChargeOn ?? DateTime.now(),
  );

  /// True once the user picks a date. Only then does an edit send the date,
  /// so saving a name change never moves the schedule.
  bool _dateTouched = false;

  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final last = DateTime(today.year + 5, today.month, today.day);
    // The calendar needs the starting day to be inside its range.
    var start = _date;
    if (start.isBefore(today)) start = today;
    if (start.isAfter(last)) start = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      // A charge in the past would never be added, so start from today.
      firstDate: today,
      lastDate: last,
      // Calendar only: hides the pencil "type a date" button.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _date = dateOnly(picked);
        _dateTouched = true;
      });
    }
  }

  Future<void> _save(String? accountId) async {
    if (!_formKey.currentState!.validate()) return;
    if (accountId == null) {
      setState(() => _error = 'Add an account first (Accounts tab).');
      return;
    }
    final name = _nameController.text.trim();
    final cents = Money.parseToCents(_amountController.text)!;
    final subscriptions = ref.read(subscriptionsProvider.notifier);
    final existing = widget.existing;

    await _run(() {
      if (existing == null) {
        return subscriptions.add(
          name: name,
          amountCents: cents,
          frequency: _frequency,
          firstChargeOn: _date,
          accountId: accountId,
          categoryId: _categoryId,
        );
      }
      final scheduleChanged = _dateTouched || _frequency != existing.frequency;
      return subscriptions.save(
        existing.copyWith(
          name: name,
          amountCents: cents,
          frequency: _frequency,
          accountId: accountId,
          categoryId: _categoryId,
        ),
        firstChargeOn: scheduleChanged ? _date : null,
      );
    });
  }

  Future<void> _togglePaused() {
    final existing = widget.existing!;
    return _run(
      () => ref
          .read(subscriptionsProvider.notifier)
          .setActive(existing.id, active: !existing.active),
    );
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this subscription?'),
        content: const Text(
          'The expenses it already added stay in your History.',
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
      () =>
          ref.read(subscriptionsProvider.notifier).remove(widget.existing!.id),
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

  /// If this subscription pays from an account that is now archived,
  /// returns that account so the form can still show it. Otherwise null.
  Account? _archivedOriginal(List<Account> active) {
    final originalId = widget.existing?.accountId;
    if (originalId == null || active.any((a) => a.id == originalId)) {
      return null;
    }
    final archived = ref.watch(archivedAccountsProvider).value ?? const [];
    return archived.where((a) => a.id == originalId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final existing = widget.existing;
    final accounts = inGroupOrder(
      ref.watch(accountsProvider).value ?? const <Account>[],
    );
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        .where((c) => c.kind == TransactionKind.expense)
        .toList();
    // Until the user picks one, use the account they used last time
    // (or their first account if that one is missing).
    final accountId =
        _accountId ??
        defaultAccountId(accounts, ref.watch(lastUsedAccountIdProvider).value);
    final balances = ref.watch(accountBalancesProvider).value;
    final monthNote = shortMonthNote(_frequency, _date);

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
                    _isEditing ? 'Edit subscription' : 'New subscription',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('subscription-name'),
                    controller: _nameController,
                    enabled: !_saving,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Spotify',
                      // Hide the "0/80" counter; the limit still applies.
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  AmountHeroField(
                    controller: _amountController,
                    color: context.appColors.expense,
                    enabled: !_saving,
                  ),
                  const _SectionLabel('Charged'),
                  SegmentedButton<SubscriptionFrequency>(
                    segments: const [
                      ButtonSegment(
                        value: SubscriptionFrequency.monthly,
                        label: Text('Monthly'),
                      ),
                      ButtonSegment(
                        value: SubscriptionFrequency.yearly,
                        label: Text('Yearly'),
                      ),
                    ],
                    selected: {_frequency},
                    showSelectedIcon: false,
                    onSelectionChanged: _saving
                        ? null
                        : (picked) => setState(() => _frequency = picked.first),
                  ),
                  const _SectionLabel('Next charge'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('date-next-charge'),
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        fullDate(_date),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _frequency == SubscriptionFrequency.monthly
                        ? 'It repeats every month on this day.'
                        : 'It repeats every year on this day.',
                    style: grey,
                  ),
                  if (monthNote != null) Text(monthNote, style: grey),
                  const _SectionLabel('Category'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        CategoryPill(
                          category: category,
                          selected: category.id == _categoryId,
                          onTap: _saving
                              ? null
                              : () => setState(
                                  () => _categoryId = category.id == _categoryId
                                      ? null
                                      : category.id,
                                ),
                        ),
                      // Quick add: opens the category form on top of this one.
                      NewCategoryPill(
                        onTap: _saving
                            ? null
                            : () => showCategoryFormSheet(
                                context,
                                kind: TransactionKind.expense,
                              ),
                      ),
                    ],
                  ),
                  const _SectionLabel('Pay from'),
                  AccountPickerCards(
                    balances: balances,
                    accounts: accounts,
                    archivedAccount: _archivedOriginal(accounts),
                    selectedId: accountId,
                    onChanged: _saving
                        ? null
                        : (id) => setState(() => _accountId = id),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'GastaDoor adds an expense for this on the day it is due '
                    '(during the night), so it shows up in your History, '
                    'budget and account balance.',
                    style: grey,
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
                onPressed: _saving ? null : () => _save(accountId),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_isEditing ? 'Save' : 'Add subscription'),
              ),
              if (existing != null) ...[
                TextButton(
                  onPressed: _saving ? null : _togglePaused,
                  child: Text(
                    existing.active
                        ? 'Pause subscription'
                        : 'Resume subscription',
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Delete subscription'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small grey heading above a part of the form (same look as the one in
/// the Add transaction form).
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

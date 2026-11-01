import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_picker_cards.dart';

/// A small grey heading above a part of the form (same look as the one in
/// the Add transaction form).
class LoanSectionLabel extends StatelessWidget {
  const LoanSectionLabel(this.text, {super.key});

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

/// A date shown on an outlined button with a calendar icon, like the date in
/// the Add transaction form. With [onClear], an X button empties it (for an
/// optional date).
class LoanDateButton extends StatelessWidget {
  const LoanDateButton({
    super.key,
    required this.date,
    required this.onTap,
    this.onClear,
    this.clearTooltip = 'Clear date',
    this.emptyText = 'Not set',
  });

  /// Null shows [emptyText].
  final DateTime? date;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String clearTooltip;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final picked = date;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(
                picked == null ? emptyText : fullDate(picked),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (picked != null && onClear != null)
            IconButton(
              tooltip: clearTooltip,
              icon: const Icon(Icons.close_rounded),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

/// Opens an iPhone-style date wheel at the bottom of the screen and returns
/// the day picked (or null if cancelled).
Future<DateTime?> pickLoanDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
}) {
  final first = dateOnly(firstDate ?? DateTime(2000));
  final last = dateOnly(DateTime.now().add(const Duration(days: 365 * 5)));
  var start = dateOnly(initial);
  if (start.isBefore(first)) start = first;
  if (start.isAfter(last)) start = last;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (_) => _DateWheelSheet(initial: start, first: first, last: last),
  );
}

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late DateTime _chosen = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_chosen),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 216,
              // The wheel uses the app's font and colors, not iOS's default.
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: theme.textTheme.titleLarge
                        ?.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: widget.initial,
                  minimumDate: widget.first,
                  maximumDate: widget.last,
                  onDateTimeChanged: (d) => _chosen = dateOnly(d),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ready-made due dates offered under the due date: a label and the day.
/// "End of month" is the last day of the month the loan was made in (or of
/// the next month, if the loan was made on that last day).
List<(String, DateTime)> dueShortcuts(DateTime lentOn) {
  final day = dateOnly(lentOn);
  var monthEnd = DateTime(day.year, day.month + 1, 0);
  if (monthEnd == day) monthEnd = DateTime(day.year, day.month + 2, 0);
  return [
    ('1 week', DateTime(day.year, day.month, day.day + 7)),
    ('2 weeks', DateTime(day.year, day.month, day.day + 14)),
    ('End of month', monthEnd),
  ];
}

/// Chips that set the due date in one tap. Tapping the chosen one again
/// clears the due date.
class DueShortcuts extends StatelessWidget {
  const DueShortcuts({
    super.key,
    required this.lentOn,
    required this.dueOn,
    required this.onChanged,
  });

  final DateTime lentOn;
  final DateTime? dueOn;

  /// Called with the new due date, or null to clear it.
  final ValueChanged<DateTime?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, date) in dueShortcuts(lentOn))
          ChoiceChip(
            label: Text(label),
            selected: dueOn == date,
            showCheckmark: false,
            onSelected: onChanged == null
                ? null
                : (on) => onChanged!(on ? date : null),
          ),
      ],
    );
  }
}

/// People you have lent to before, as chips: tap one to fill in the name.
class RecentBorrowers extends StatelessWidget {
  const RecentBorrowers({super.key, required this.names, required this.onPick});

  final List<String> names;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in names)
            ActionChip(
              label: Text(name),
              onPressed: onPick == null ? null : () => onPick!(name),
            ),
        ],
      ),
    );
  }
}

/// "Should this change an account?" for a loan or a repayment.
///
/// - A heading ([title]) with a switch on its right.
/// - Switch on: the same account pills as the Add transaction form, to pick
///   the account the money leaves (or goes into). Under them, what the
///   balance becomes.
/// - Switch off: no account changes. This is for money that moved before you
///   started tracking, when the starting balance already counted it.
///
/// The screen owns the state ([useAccount], [accountId]); this widget only
/// shows it and reports taps.
class AccountChoice extends ConsumerWidget {
  const AccountChoice({
    super.key,
    required this.title,
    required this.onHelp,
    required this.offHelp,
    required this.useAccount,
    required this.accountId,
    required this.onUseAccountChanged,
    required this.onAccountPicked,
    this.amountCents,
    this.moneyLeaves = true,
    this.enabled = true,
  });

  final String title;

  /// Explains what happens when the switch is on / off.
  final String onHelp;
  final String offHelp;
  final bool useAccount;
  final String? accountId;
  final ValueChanged<bool> onUseAccountChanged;
  final ValueChanged<String> onAccountPicked;

  /// The amount typed so far (null or 0 while empty), for the balance preview.
  final int? amountCents;

  /// True when the money leaves the account (a loan); false when it goes in
  /// (a repayment).
  final bool moneyLeaves;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final balances = ref.watch(accountBalancesProvider).value;
    final selected = accounts.where((a) => a.id == accountId).firstOrNull;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The heading, with the switch at the right edge.
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: useAccount,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: enabled ? onUseAccountChanged : null,
              ),
            ],
          ),
        ),
        if (useAccount) ...[
          const SizedBox(height: 8),
          AccountPickerCards(
            accounts: accounts,
            selectedId: accountId,
            balances: balances,
            onChanged: enabled ? onAccountPicked : null,
          ),
        ],
        const SizedBox(height: 8),
        _help(context, selected, accounts, balances),
      ],
    );
  }

  /// The small line under the pills: what the switch does, or (with an
  /// amount and an account) what the balance becomes.
  Widget _help(
    BuildContext context,
    Account? selected,
    List<Account> accounts,
    Map<String, int>? balances,
  ) {
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!useAccount) return Text(offHelp, style: grey);

    final balance = selected == null ? null : balances?[selected.id];
    final amount = amountCents;
    if (selected == null || balance == null || amount == null || amount <= 0) {
      return Text(onHelp, style: grey);
    }

    final name = accountLabel(selected, accounts);
    final after = moneyLeaves ? balance - amount : balance + amount;
    if (moneyLeaves && after < 0) {
      return Text(
        "That's more than $name has (${Money.format(balance)}). If you lent "
        'it before you started tracking, turn the switch off.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: context.appColors.expense,
        ),
      );
    }
    return Text(
      '$name: ${Money.format(balance)} → ${Money.format(after)}',
      style: grey,
    );
  }
}

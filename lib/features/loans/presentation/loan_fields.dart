import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/account_groups.dart';
import '../../accounts/presentation/account_avatar.dart';
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

/// A white rounded card holding rows with thin lines between them, like a
/// group in the iPhone Settings app.
class LoanGroup extends StatelessWidget {
  const LoanGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            child,
          ],
        ],
      ),
    );
  }
}

/// One row of a [LoanGroup]: the label on the left, then (optionally) a small
/// [leading] picture and a grey [value], and a [trailing] widget on the right.
/// With [onTap] the whole row is tappable and shows an arrow by default.
class LoanRow extends StatelessWidget {
  const LoanRow({
    super.key,
    required this.label,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = theme.colorScheme.onSurfaceVariant;
    final end =
        trailing ??
        (onTap == null ? null : Icon(Icons.chevron_right_rounded, color: grey));

    final labelText = Text(label, style: theme.textTheme.bodyLarge);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              if (value == null && leading == null)
                // Only a label (like a switch row): it may use all the room
                // that is left, and wrap if it is long.
                Expanded(child: labelText)
              else ...[
                labelText,
                const SizedBox(width: 12),
                // The value takes what is left and is cut short with "..."
                // rather than overflowing.
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
                      if (value != null)
                        Flexible(
                          child: Text(
                            value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (end != null) ...[const SizedBox(width: 4), end],
            ],
          ),
        ),
      ),
    );
  }
}

/// A date row: the label, the date in grey, and an arrow. With [onClear], an
/// X button empties it (for an optional date).
class LoanDateRow extends StatelessWidget {
  const LoanDateRow({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
    this.emptyText = 'Not set',
  });

  final String label;

  /// Null shows [emptyText].
  final DateTime? date;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final picked = date;
    return LoanRow(
      label: label,
      value: picked == null ? emptyText : friendlyDate(picked),
      onTap: onTap,
      trailing: picked != null && onClear != null
          ? IconButton(
              tooltip: 'Clear $label',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.cancel_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: onClear,
            )
          : null,
    );
  }
}

/// A "Note" row with the text box right in the row: no border, no counter.
/// The 500-letter limit still applies.
class LoanNoteRow extends StatelessWidget {
  const LoanNoteRow({
    super.key,
    required this.controller,
    required this.enabled,
    this.hint = 'Add a note',
  });

  final TextEditingController controller;
  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text('Note', style: theme.textTheme.bodyLarge),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: theme.textTheme.bodyLarge,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              decoration: InputDecoration.collapsed(hintText: hint),
            ),
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

/// The ready-made due dates offered under the form: a label and the day.
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
/// - Switch on: pick the account the money leaves (or goes into). It shows
///   as one row; tap the row to open the account pills, tap a pill to close
///   them again. Under it, what the balance becomes.
/// - Switch off: no account changes. This is for money that moved before you
///   started tracking, when the starting balance already counted it.
///
/// The screen owns the state ([useAccount], [accountId]); this widget only
/// shows it and reports taps. Whether the pills are open is its own business.
class AccountChoice extends ConsumerStatefulWidget {
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
  ConsumerState<AccountChoice> createState() => _AccountChoiceState();
}

class _AccountChoiceState extends ConsumerState<AccountChoice> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final balances = ref.watch(accountBalancesProvider).value;
    final selected = accounts.where((a) => a.id == w.accountId).firstOrNull;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoanGroup(
          children: [
            LoanRow(
              label: w.title,
              onTap: w.enabled
                  ? () => w.onUseAccountChanged(!w.useAccount)
                  : null,
              trailing: CupertinoSwitch(
                value: w.useAccount,
                activeTrackColor: theme.colorScheme.primary,
                onChanged: w.enabled ? w.onUseAccountChanged : null,
              ),
            ),
            if (w.useAccount)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LoanRow(
                    key: const Key('account-row'),
                    label: 'Account',
                    leading: selected == null
                        ? null
                        : AccountAvatar(account: selected, size: 22),
                    value: selected == null
                        ? 'Choose'
                        : accountLabel(selected, accounts),
                    onTap: w.enabled
                        ? () => setState(() => _open = !_open)
                        : null,
                    trailing: Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _open
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Divider(height: 1, indent: 16),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: AccountPickerCards(
                                  accounts: accounts,
                                  selectedId: w.accountId,
                                  balances: balances,
                                  onChanged: w.enabled
                                      ? (id) {
                                          setState(() => _open = false);
                                          w.onAccountPicked(id);
                                        }
                                      : null,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: _help(context, selected, accounts, balances),
        ),
      ],
    );
  }

  /// The small line under the card: what the switch does, or (with an amount
  /// and an account) what the balance becomes.
  Widget _help(
    BuildContext context,
    Account? selected,
    List<Account> accounts,
    Map<String, int>? balances,
  ) {
    final w = widget;
    final theme = Theme.of(context);
    final grey = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!w.useAccount) return Text(w.offHelp, style: grey);

    final balance = selected == null ? null : balances?[selected.id];
    final amount = w.amountCents;
    if (selected == null || balance == null || amount == null || amount <= 0) {
      return Text(w.onHelp, style: grey);
    }

    final name = accountLabel(selected, accounts);
    final after = w.moneyLeaves ? balance - amount : balance + amount;
    if (w.moneyLeaves && after < 0) {
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

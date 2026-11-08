import 'package:flutter/material.dart';
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

/// Opens the calendar (the same one the Add transaction form uses) and
/// returns the day picked, or null if cancelled.
Future<DateTime?> pickLoanDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
}) async {
  final first = dateOnly(firstDate ?? DateTime(2000));
  final last = DateTime.now().add(const Duration(days: 365 * 5));
  // The calendar needs the starting day to be inside its range.
  var start = dateOnly(initial);
  if (start.isBefore(first)) start = first;
  if (start.isAfter(last)) start = dateOnly(last);

  final picked = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: first,
    lastDate: last,
    // Calendar only: hides the pencil "type a date" button.
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
  return picked == null ? null : dateOnly(picked);
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
/// - Switch on: one box shows the account that will be used (and its
///   balance). Tap it and the account pills, the same ones as in the Add
///   transaction form, slide open; tap a pill and they close again. Under
///   it, what the balance becomes.
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
        // The heading, with the switch at the right edge.
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  w.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Switch(
                value: w.useAccount,
                onChanged: w.enabled ? w.onUseAccountChanged : null,
              ),
            ],
          ),
        ),
        if (w.useAccount) ...[
          const SizedBox(height: 8),
          _AccountBox(
            account: selected,
            name: selected == null ? null : accountLabel(selected, accounts),
            balanceCents: selected == null ? null : balances?[selected.id],
            open: _open,
            onTap: w.enabled ? () => setState(() => _open = !_open) : null,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
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
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
        const SizedBox(height: 8),
        _help(context, selected, accounts, balances),
      ],
    );
  }

  /// The small line under the account: what the switch does, or (with an
  /// amount and an account) what the balance becomes.
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

/// The closed account picker: an outlined box with the account's picture,
/// its name, its balance, and an arrow that points down (closed) or up (open).
class _AccountBox extends StatelessWidget {
  const _AccountBox({
    required this.account,
    required this.name,
    required this.balanceCents,
    required this.open,
    required this.onTap,
  });

  final Account? account;
  final String? name;
  final int? balanceCents;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = theme.colorScheme.onSurfaceVariant;
    final cents = balanceCents;

    return OutlinedButton(
      key: const Key('account-row'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Row(
        children: [
          if (account != null) ...[
            AccountAvatar(account: account!, size: 24),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              name ?? 'Choose an account',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (cents != null) ...[
            const SizedBox(width: 8),
            Text(
              Money.format(cents),
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cents < 0 ? context.appColors.expense : grey,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: grey,
          ),
        ],
      ),
    );
  }
}

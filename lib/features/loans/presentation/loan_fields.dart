import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../accounts/data/accounts_provider.dart';
import '../../accounts/presentation/account_picker_cards.dart';

/// A tappable box that shows a date and opens the calendar.
/// With [onClear], an X button empties it (for an optional date).
class LoanDateField extends StatelessWidget {
  const LoanDateField({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: picked != null && onClear != null
              ? IconButton(
                  tooltip: 'Clear $label',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_rounded, size: 20),
        ),
        child: Text(picked == null ? emptyText : fullDate(picked)),
      ),
    );
  }
}

/// Opens the calendar and returns the day picked (or null if cancelled).
Future<DateTime?> pickLoanDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate ?? DateTime(2000),
    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    // Calendar only: hides the pencil "type a date" button.
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
  return picked == null ? null : dateOnly(picked);
}

/// "Should this change an account?" for a loan or a repayment.
///
/// - Switch on: pick the account the money leaves (or goes into).
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
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final balances = ref.watch(accountBalancesProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(useAccount ? onHelp : offHelp),
          value: useAccount,
          onChanged: enabled ? onUseAccountChanged : null,
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
      ],
    );
  }
}

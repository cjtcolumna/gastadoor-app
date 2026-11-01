import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/transaction.dart';

/// The Expense | Income | Transfer toggle. The chosen side is tinted in its
/// own color: red for expense, green for income, blue for transfer.
///
/// Add transaction shows all three. Pass fewer [kinds] to show fewer (the
/// Budget page has no Transfer).
class KindSwitch extends StatelessWidget {
  const KindSwitch({
    super.key,
    required this.kind,
    required this.onChanged,
    this.kinds = const [
      TransactionKind.expense,
      TransactionKind.income,
      TransactionKind.transfer,
    ],
  });

  final TransactionKind kind;

  /// Null turns the whole switch off (for example while saving).
  final ValueChanged<TransactionKind>? onChanged;

  /// Which sides to show, left to right.
  final List<TransactionKind> kinds;

  @override
  Widget build(BuildContext context) {
    final money = context.appColors;
    final (color, soft) = switch (kind) {
      TransactionKind.expense => (money.expense, money.expenseSoft),
      TransactionKind.income => (money.income, money.incomeSoft),
      TransactionKind.transfer => (money.transfer, money.transferSoft),
    };

    return SegmentedButton<TransactionKind>(
      segments: [
        for (final k in kinds)
          ButtonSegment(
            value: k,
            label: Text(switch (k) {
              TransactionKind.expense => 'Expense',
              TransactionKind.income => 'Income',
              TransactionKind.transfer => 'Transfer',
            }),
            // Same icons as Home and History: ↗ out, ↙ in, ⇄ between.
            icon: Icon(switch (k) {
              TransactionKind.expense => Icons.north_east_rounded,
              TransactionKind.income => Icons.south_west_rounded,
              TransactionKind.transfer => Icons.swap_horiz_rounded,
            }),
          ),
      ],
      selected: {kind},
      // Keep each side's own icon when selected (no check mark swap).
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: soft,
        selectedForegroundColor: color,
        // Three tabs on a phone: keep them snug so the words fit.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
    );
  }
}

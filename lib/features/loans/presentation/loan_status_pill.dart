import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/loan_summary.dart';

/// A small rounded label with a loan's status, in the app's money colors:
/// amber = waiting, blue = partly paid, red = overdue, green = paid back.
/// Each is a pale fill with strong text, like the soft circles in History.
class LoanStatusPill extends StatelessWidget {
  const LoanStatusPill(this.status, {super.key});

  final LoanStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (text, fill) = switch (status) {
      // Amber text on a pale fill is hard to read, so darken it a little.
      LoanStatus.outstanding => (
        Color.lerp(colors.warning, Colors.black, 0.4)!,
        colors.warning.withValues(alpha: 0.18),
      ),
      LoanStatus.partlyPaid => (colors.transfer, colors.transferSoft),
      LoanStatus.overdue => (colors.expense, colors.expenseSoft),
      LoanStatus.paid => (colors.income, colors.incomeSoft),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          statusLabel(status),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: text, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

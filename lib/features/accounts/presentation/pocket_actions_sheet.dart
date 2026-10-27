import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_form_sheet.dart';
import '../domain/account.dart';
import '../domain/pocket_goal.dart';
import 'pocket_form_sheet.dart';
import 'pocket_visuals.dart';

/// The menu that opens when you tap a sub-account bubble:
/// Add money, Take out, or Edit.
///
/// Add money and Take out open the Transfer form already filled in, so you
/// only type the amount. A transfer isn't spending or income, so it doesn't
/// change Insights, budgets, or the main account's total.
Future<void> showPocketActions(
  BuildContext context, {
  required Account parent,
  required Account pocket,
  required int balanceCents,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the floating tab bar
    // Grow to fit the menu, and scroll if it still doesn't fit
    // (small phones, big text).
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      // Close this menu, then open the next form from the page underneath.
      void then(void Function() open) {
        Navigator.of(sheetContext).pop();
        open();
      }

      return SingleChildScrollView(
        child: Padding(
          // Keep the last row clear of the iPhone's home bar.
          padding: EdgeInsets.only(
            bottom: 12 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(pocket: pocket, balanceCents: balanceCents),
              const Divider(height: 1),
              ListTile(
                leading: const _ActionIcon(Icons.south_rounded),
                title: const Text('Add money'),
                subtitle: Text('From ${parent.name}'),
                onTap: () => then(
                  () => showTransactionFormSheet(
                    context,
                    kind: TransactionKind.transfer,
                    accountId: parent.id,
                    toAccountId: pocket.id,
                  ),
                ),
              ),
              ListTile(
                leading: const _ActionIcon(Icons.north_rounded),
                title: const Text('Take out'),
                subtitle: Text('Back to ${parent.name}'),
                onTap: () => then(
                  () => showTransactionFormSheet(
                    context,
                    kind: TransactionKind.transfer,
                    accountId: pocket.id,
                    toAccountId: parent.id,
                  ),
                ),
              ),
              ListTile(
                leading: const _ActionIcon(Icons.edit_rounded),
                title: const Text('Edit sub-account'),
                subtitle: const Text('Name, icon, goal'),
                onTap: () => then(
                  () => showPocketFormSheet(
                    context,
                    parent: parent,
                    pocket: pocket,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.pocket, required this.balanceCents});

  final Account pocket;
  final int balanceCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      leading: CircleAvatar(
        backgroundColor: context.appColors.incomeSoft,
        foregroundColor: theme.colorScheme.primary,
        child: Icon(pocketIconFor(pocket.icon)),
      ),
      title: Text(
        pocket.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${Money.format(balanceCents)} · '
        '${goalText(balanceCents, pocket.goalCents)}',
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurface,
      child: Icon(icon, size: 20),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import 'account_type_ui.dart';

/// One account row: icon, name, type, and balance on the right.
/// Used on both the Home dashboard and the Accounts tab.
class AccountBalanceTile extends StatelessWidget {
  const AccountBalanceTile({
    super.key,
    required this.account,
    required this.balanceCents,
    this.onTap,
  });

  final Account account;
  final int balanceCents;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = context.appColors;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: money.incomeSoft,
        foregroundColor: theme.colorScheme.primary,
        child: Icon(account.type.icon, size: 22),
      ),
      title: Text(
        account.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(account.type.label),
      trailing: Text(
        Money.format(balanceCents),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          // Money you owe shows in red.
          color: balanceCents < 0 ? money.expense : theme.colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: onTap,
    );
  }
}

/// A rounded card holding a list of rows, with thin lines between them.
class AccountsCard extends StatelessWidget {
  const AccountsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            child,
          ],
        ],
      ),
    );
  }
}

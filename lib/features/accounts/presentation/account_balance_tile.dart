import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import '../domain/account_groups.dart';
import 'account_type_ui.dart';

/// The line under a main account's name: "Bank", or "Bank · 2 sub-accounts".
String groupSubtitle(AccountGroup group) {
  final type = group.account.type.label;
  return switch (group.children.length) {
    0 => type,
    1 => '$type · 1 sub-account',
    final n => '$type · $n sub-accounts',
  };
}

/// True when the phone's text is set much bigger than normal. Rows then
/// put the amount under the name, so long names and amounts both fit.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) > 13;

/// One account row: icon, name, type, and balance on the right.
/// Used on both the Home dashboard and the Accounts tab.
class AccountBalanceTile extends StatelessWidget {
  const AccountBalanceTile({
    super.key,
    required this.account,
    required this.balanceCents,
    this.subtitle,
    this.onTap,
  });

  final Account account;
  final int balanceCents;

  /// The line under the name. Defaults to the account type, e.g. "Bank".
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = context.appColors;
    final amount = Text(
      Money.format(balanceCents),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        // Money you owe shows in red.
        color: balanceCents < 0 ? money.expense : theme.colorScheme.onSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final details = Text(subtitle ?? account.type.label);
    final large = isLargeText(context);

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
      subtitle: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, amount],
            )
          : details,
      trailing: large ? null : amount,
      onTap: onTap,
    );
  }
}

/// A smaller, indented row under a main account: its own "Main balance",
/// or one of its pockets (Travel, Emergency Fund...).
class PocketTile extends StatelessWidget {
  const PocketTile({
    super.key,
    required this.name,
    required this.balanceCents,
    this.isMain = false,
    this.onTap,
  });

  final String name;
  final int balanceCents;

  /// True for the parent's own money ("Main balance").
  final bool isMain;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final money = context.appColors;
    final muted = theme.colorScheme.onSurfaceVariant;
    final large = isLargeText(context);
    final amount = Text(
      Money.format(balanceCents),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: balanceCents < 0 ? money.expense : muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return ListTile(
      dense: true,
      // Lines up with the main account's name, so it reads as "inside".
      // With very big text, indent less to leave room for the words.
      contentPadding: EdgeInsetsDirectional.only(
        start: large ? 40 : 72,
        end: 16,
      ),
      minLeadingWidth: 0,
      horizontalTitleGap: 8,
      leading: Icon(
        isMain ? Icons.account_balance_wallet_rounded : Icons.savings_rounded,
        size: 18,
        color: muted,
      ),
      title: Text(
        name,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isMain ? muted : null,
        ),
      ),
      subtitle: large ? amount : null,
      trailing: large ? null : amount,
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

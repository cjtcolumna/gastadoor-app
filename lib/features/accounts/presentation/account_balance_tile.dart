import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../domain/account.dart';
import '../domain/account_groups.dart';
import 'account_avatar.dart';
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
    this.showChevron = false,
    this.onTap,
  });

  final Account account;
  final int balanceCents;

  /// The line under the name. Defaults to the account type, e.g. "Bank".
  final String? subtitle;

  /// Show a › at the end, meaning "tap to open its page".
  final bool showChevron;
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
    final chevron = Icon(
      Icons.chevron_right_rounded,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListTile(
      // The bank's own icon (GCash, BDO...) or the usual round icon.
      leading: AccountAvatar(account: account),
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
      trailing: switch ((large, showChevron)) {
        (true, true) => chevron,
        (true, false) => null,
        (false, true) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [amount, const SizedBox(width: 4), chevron],
        ),
        (false, false) => amount,
      },
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

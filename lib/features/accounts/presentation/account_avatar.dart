import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/account.dart';
import '../domain/ph_banks.dart';
import 'pocket_visuals.dart';

/// The bank a main account belongs to, going by its name. Sub-accounts
/// (Travel, Emergency Fund...) keep their own icons, so they get null.
PhBank? bankOf(Account account) =>
    account.parentId == null ? bankForName(account.name) : null;

/// An account's picture: its bank's icon (GCash, BDO...) as a small
/// rounded square, or the usual round green icon for anything else.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.size = 40});

  final Account account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bank = bankOf(account);
    if (bank != null) return BankIcon(bank: bank, size: size);

    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.appColors.incomeSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        accountIconFor(account),
        size: size * 0.55,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// A bank's icon as a rounded square, like a tiny app icon. A thin border
/// keeps white icons (like MariBank's) from blending into white cards.
class BankIcon extends StatelessWidget {
  const BankIcon({super.key, required this.bank, this.size = 40});

  final PhBank bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          bank.iconAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          // If the picture ever fails to load, show the brand color.
          errorBuilder: (context, _, _) => ColoredBox(color: Color(bank.color)),
        ),
      ),
    );
  }
}

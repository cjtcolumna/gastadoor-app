import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../domain/account.dart';
import 'account_type_ui.dart';

/// The icon for a saved name. Sub-accounts pick from the same list as
/// categories ([appIcons]). Empty or unknown names get the piggy bank.
IconData pocketIconFor(String? name) =>
    appIconFor(name, fallback: Icons.savings_rounded);

/// The icon to show for any account: a pocket's own icon, or the
/// account type's icon (bank, cash...) for a main account.
IconData accountIconFor(Account account) =>
    account.parentId == null ? account.type.icon : pocketIconFor(account.icon);

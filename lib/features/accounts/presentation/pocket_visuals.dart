import 'package:flutter/material.dart';

import '../domain/account.dart';
import 'account_type_ui.dart';

/// Every icon a sub-account (pocket) can use. The database saves the short
/// name on the left; the app turns it into the Flutter icon here.
///
/// Listed by name (not built from numbers) so release builds keep them.
const pocketIcons = <String, IconData>{
  'savings': Icons.savings_rounded,
  'flight': Icons.flight_rounded,
  'beach': Icons.beach_access_rounded,
  'emergency': Icons.health_and_safety_rounded,
  'health': Icons.medical_services_rounded,
  'home': Icons.home_rounded,
  'car': Icons.directions_car_rounded,
  'school': Icons.school_rounded,
  'gift': Icons.card_giftcard_rounded,
  'gadget': Icons.devices_rounded,
  'wedding': Icons.favorite_rounded,
  'baby': Icons.child_friendly_rounded,
  'pets': Icons.pets_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'games': Icons.sports_esports_rounded,
  'celebration': Icons.celebration_rounded,
  'business': Icons.storefront_rounded,
  'invest': Icons.trending_up_rounded,
};

/// The icon for a saved name. Empty or unknown names get the piggy bank.
IconData pocketIconFor(String? name) =>
    pocketIcons[name] ?? Icons.savings_rounded;

/// The icon to show for any account: a pocket's own icon, or the
/// account type's icon (bank, cash...) for a main account.
IconData accountIconFor(Account account) =>
    account.parentId == null ? account.type.icon : pocketIconFor(account.icon);

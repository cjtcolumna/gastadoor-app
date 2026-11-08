import 'package:flutter/material.dart';

/// Every icon that categories and sub-accounts (pockets) can use. Both
/// pickers show this one list, so adding or removing an icon here changes
/// both of them. The database saves the short name on the left (e.g.
/// 'restaurant'); the app turns it into the Flutter icon here.
///
/// Icons must be listed by name like this (not built from numbers saved in
/// the database) so release builds keep them. Add new ones to this map.
///
/// The pickers show the icons in the order written here, so keep similar
/// ones next to each other (travel, food, shopping, home, health, fun...).
///
/// Taking a name out of this map is safe: something that already saved it
/// shows its fallback icon (see [appIconFor]) until you pick another.
/// To give it a replacement instead, list it in [retiredIconNames].
const appIcons = <String, IconData>{
  'bus': Icons.directions_bus_rounded,
  'car': Icons.directions_car_rounded,
  'flight': Icons.flight_rounded,
  'restaurant': Icons.restaurant_rounded,
  'cafe': Icons.local_cafe_rounded,
  'groceries': Icons.local_grocery_store_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'home': Icons.home_rounded,
  'receipt': Icons.receipt_long_rounded,
  'phone': Icons.phone_iphone_rounded,
  'gadget': Icons.devices_rounded,
  'health': Icons.medical_services_rounded,
  'emergency': Icons.health_and_safety_rounded,
  'fitness': Icons.fitness_center_rounded,
  // Flutter's built-in icons have no lipstick, so this is the face with
  // sparkles, the usual "beauty" icon. The saved name stays 'lipstick', so a
  // real lipstick drawing can replace it here later without touching data.
  'lipstick': Icons.face_retouching_natural_rounded,
  'pets': Icons.pets_rounded,
  'games': Icons.sports_esports_rounded,
  'celebration': Icons.celebration_rounded,
  'wedding': Icons.favorite_rounded,
  // A gift box (the old card-with-ribbon looked like a gift card).
  'gift': Icons.redeem_rounded,
  'savings': Icons.savings_rounded,
  'work': Icons.work_rounded,
  'category': Icons.category_rounded,
};

/// Icon names that are no longer offered, mapped to the icon that now takes
/// their place, e.g. `{'shopping': 'groceries'}`. Anything that saved the old
/// name shows the new icon (and saves the new name the next time it is
/// edited), so nothing has to be changed in the database. Empty for now.
const retiredIconNames = <String, String>{};

/// The name to use for a saved icon name: a retired one is swapped for its
/// replacement, anything else comes back as it was.
String? currentIconName(String? saved) => retiredIconNames[saved] ?? saved;

/// Keeps a saved icon name if the app still offers it, else [fallback].
/// Forms use this so an old or removed name doesn't stay saved by accident.
String knownIconName(String? saved, {required String fallback}) {
  final name = currentIconName(saved);
  return name != null && appIcons.containsKey(name) ? name : fallback;
}

/// The icon for a saved name, or [fallback] for an unknown one (old emojis,
/// removed icons, or nothing saved).
IconData appIconFor(String? saved, {required IconData fallback}) =>
    appIcons[currentIconName(saved)] ?? fallback;

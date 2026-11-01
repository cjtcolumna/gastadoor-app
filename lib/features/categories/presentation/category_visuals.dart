import 'package:flutter/material.dart';

/// Every icon a category can use. The database saves the short name on the
/// left (e.g. 'restaurant'); the app turns it into the Flutter icon here.
///
/// Icons must be listed by name like this (not built from numbers saved in
/// the database) so release builds keep them. Add new ones to this map.
///
/// Taking a name out of this map is safe: a category that already saved it
/// shows the plain tag icon (see [categoryIconFor]) until you pick another.
/// To give it a replacement instead, list it in [retiredIconNames].
const categoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant_rounded,
  'groceries': Icons.local_grocery_store_rounded,
  'cafe': Icons.local_cafe_rounded,
  'bus': Icons.directions_bus_rounded,
  'car': Icons.directions_car_rounded,
  'flight': Icons.flight_rounded,
  'receipt': Icons.receipt_long_rounded,
  'home': Icons.home_rounded,
  'phone': Icons.phone_iphone_rounded,
  // Flutter's built-in icons have no lipstick, so this is the face with
  // sparkles, the usual "beauty" icon. The saved name stays 'lipstick', so a
  // real lipstick drawing can replace it here later without touching data.
  'lipstick': Icons.face_retouching_natural_rounded,
  'health': Icons.medical_services_rounded,
  'fitness': Icons.fitness_center_rounded,
  'pets': Icons.pets_rounded,
  'celebration': Icons.celebration_rounded,
  'category': Icons.category_rounded,
  'work': Icons.work_rounded,
  // A gift box (the old card-with-ribbon looked like a gift card).
  'gift': Icons.redeem_rounded,
  'savings': Icons.savings_rounded,
};

/// Every color a category can use, saved in the database by name.
const categoryColors = <String, Color>{
  'orange': Color(0xFFEF6C00),
  'blue': Color(0xFF1E88E5),
  // Deeper than Material amber so it stays visible on white (3:1 contrast).
  'amber': Color(0xFFC98500),
  'pink': Color(0xFFD81B60),
  'red': Color(0xFFE53935),
  'purple': Color(0xFF8E24AA),
  'grey': Color(0xFF757575),
  'green': Color(0xFF43A047),
  'teal': Color(0xFF00897B),
  'indigo': Color(0xFF3949AB),
  'brown': Color(0xFF6D4C41),
};

/// Icon names that are no longer offered, mapped to the icon that now takes
/// their place. Categories that saved the old name show the new icon (and
/// save the new name the next time they are edited), so nothing has to be
/// changed in the database.
const retiredIconNames = <String, String>{
  // The shopping bag was removed; the grocery cart is its replacement.
  'shopping': 'groceries',
};

/// The name to use for a saved icon name: a retired one is swapped for its
/// replacement, anything else comes back as it was.
String? currentIconName(String? saved) => retiredIconNames[saved] ?? saved;

/// The icon for a saved name. Unknown names (or old emojis) get a tag icon.
IconData categoryIconFor(String? name) =>
    categoryIcons[currentIconName(name)] ?? Icons.label_outline_rounded;

/// The color for a saved name, or the app's main color if there's none.
Color categoryColorFor(String? name, ColorScheme scheme) =>
    categoryColors[name] ?? scheme.primary;

/// A category's icon on a soft circle of its color.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.radius = 20,
  });

  /// The saved names, e.g. icon: 'restaurant', color: 'orange'.
  final String? icon;
  final String? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tint = categoryColorFor(color, Theme.of(context).colorScheme);
    return CircleAvatar(
      radius: radius,
      backgroundColor: tint.withValues(alpha: 0.16),
      child: Icon(categoryIconFor(icon), color: tint, size: radius),
    );
  }
}

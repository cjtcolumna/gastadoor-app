import 'package:flutter/material.dart';

/// Every icon a category can use. The database saves the short name on the
/// left (e.g. 'restaurant'); the app turns it into the Flutter icon here.
///
/// Icons must be listed by name like this (not built from numbers saved in
/// the database) so release builds keep them. Add new ones to this map.
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
  'shopping': Icons.shopping_bag_rounded,
  'health': Icons.medical_services_rounded,
  'fitness': Icons.fitness_center_rounded,
  'school': Icons.school_rounded,
  'pets': Icons.pets_rounded,
  'celebration': Icons.celebration_rounded,
  'movie': Icons.movie_rounded,
  'category': Icons.category_rounded,
  'work': Icons.work_rounded,
  'gift': Icons.card_giftcard_rounded,
  'savings': Icons.savings_rounded,
};

/// Every color a category can use, saved in the database by name.
const categoryColors = <String, Color>{
  'orange': Color(0xFFEF6C00),
  'blue': Color(0xFF1E88E5),
  'amber': Color(0xFFFFA000),
  'pink': Color(0xFFD81B60),
  'red': Color(0xFFE53935),
  'purple': Color(0xFF8E24AA),
  'grey': Color(0xFF757575),
  'green': Color(0xFF43A047),
  'teal': Color(0xFF00897B),
  'indigo': Color(0xFF3949AB),
  'brown': Color(0xFF6D4C41),
};

/// The icon for a saved name. Unknown names (or old emojis) get a tag icon.
IconData categoryIconFor(String? name) =>
    categoryIcons[name] ?? Icons.label_outline_rounded;

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

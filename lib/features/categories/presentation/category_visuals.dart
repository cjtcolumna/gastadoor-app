import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';

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

/// The icon for a saved name. Unknown names (or old emojis) get a tag icon.
IconData categoryIconFor(String? name) =>
    appIconFor(name, fallback: Icons.label_outline_rounded);

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

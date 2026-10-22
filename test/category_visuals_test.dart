import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/categories/domain/default_categories.dart';
import 'package:gastadoor/features/categories/presentation/category_visuals.dart';

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.green);

  test('every starter category uses an icon and color that exist', () {
    for (final c in defaultCategories) {
      expect(categoryIcons, contains(c.icon), reason: '${c.name} icon');
      expect(categoryColors, contains(c.color), reason: '${c.name} color');
    }
  });

  test('known names turn into Flutter icons and colors', () {
    expect(categoryIconFor('restaurant'), Icons.restaurant_rounded);
    expect(categoryColorFor('orange', scheme), const Color(0xFFEF6C00));
  });

  test('unknown names, old emojis, and null get safe fallbacks', () {
    expect(categoryIconFor('🍔'), Icons.label_outline_rounded);
    expect(categoryIconFor(null), Icons.label_outline_rounded);
    expect(categoryColorFor('sparkly', scheme), scheme.primary);
    expect(categoryColorFor(null, scheme), scheme.primary);
  });
}

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

  test('lipstick is offered', () {
    expect(categoryIcons, contains('lipstick'));
    expect(categoryIconFor('lipstick'), Icons.face_retouching_natural_rounded);
  });

  test('the grocery, school and movie icons are no longer offered', () {
    for (final removed in ['groceries', 'school', 'movie']) {
      expect(categoryIcons, isNot(contains(removed)), reason: removed);
    }
  });

  test('a category that saved a removed icon shows the tag icon', () {
    // Nothing breaks: it just looks plain until you pick a new icon.
    for (final removed in ['groceries', 'school', 'movie']) {
      expect(categoryIconFor(removed), Icons.label_outline_rounded);
    }
  });

  test('the gift icon is a gift box, not the old card', () {
    expect(categoryIconFor('gift'), Icons.redeem_rounded);
    expect(categoryIconFor('gift'), isNot(Icons.card_giftcard_rounded));
  });

  test('no two names share the same icon', () {
    final icons = categoryIcons.values.toSet();
    expect(icons.length, categoryIcons.length);
  });

  test('unknown names, old emojis, and null get safe fallbacks', () {
    expect(categoryIconFor('🍔'), Icons.label_outline_rounded);
    expect(categoryIconFor(null), Icons.label_outline_rounded);
    expect(categoryColorFor('sparkly', scheme), scheme.primary);
    expect(categoryColorFor(null, scheme), scheme.primary);
  });
}

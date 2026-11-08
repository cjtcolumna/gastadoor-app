import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_icons.dart';
import 'package:gastadoor/features/accounts/presentation/pocket_visuals.dart';
import 'package:gastadoor/features/categories/presentation/category_visuals.dart';

void main() {
  test('no two names share the same icon', () {
    final icons = appIcons.values.toSet();
    expect(icons.length, appIcons.length);
  });

  test('the five icons added from the sub-account list are offered', () {
    expect(appIcons, containsPair('games', Icons.sports_esports_rounded));
    expect(appIcons, containsPair('shopping', Icons.shopping_bag_rounded));
    expect(appIcons, containsPair('wedding', Icons.favorite_rounded));
    expect(
      appIcons,
      containsPair('emergency', Icons.health_and_safety_rounded),
    );
    expect(appIcons, containsPair('gadget', Icons.devices_rounded));
  });

  test('categories and sub-accounts draw every offered name the same way', () {
    for (final entry in appIcons.entries) {
      expect(categoryIconFor(entry.key), entry.value, reason: entry.key);
      expect(pocketIconFor(entry.key), entry.value, reason: entry.key);
    }
  });

  test('a sub-account gift is a gift box like the category one', () {
    expect(pocketIconFor('gift'), Icons.redeem_rounded);
  });

  test('a sub-account that saved a removed icon shows the piggy bank', () {
    for (final removed in ['beach', 'school', 'baby', 'business', 'invest']) {
      expect(pocketIconFor(removed), Icons.savings_rounded, reason: removed);
    }
    expect(pocketIconFor(null), Icons.savings_rounded);
  });

  test('forms keep a known name and replace an unknown one', () {
    expect(knownIconName('games', fallback: 'savings'), 'games');
    expect(knownIconName('beach', fallback: 'savings'), 'savings');
    expect(knownIconName('🍔', fallback: 'category'), 'category');
    expect(knownIconName(null, fallback: 'category'), 'category');
  });

  test('nothing is retired right now, so saved names are left as they are', () {
    expect(retiredIconNames, isEmpty);
    expect(currentIconName('restaurant'), 'restaurant');
    expect(currentIconName(null), isNull);
  });
}

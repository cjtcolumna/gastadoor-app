import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// True if the chip around [label] would paint a check mark when selected.
/// Chips draw their check mark directly (it's not an Icon widget), so tests
/// look at the chip's setting, falling back to the theme like Flutter does.
bool checkmarksShown(WidgetTester tester, Finder label) {
  final chipFinder = find.ancestor(
    of: label,
    matching: find.byType(ChoiceChip),
  );
  final chip = tester.widget<ChoiceChip>(chipFinder);
  final theme = ChipTheme.of(tester.element(chipFinder));
  return chip.showCheckmark ?? theme.showCheckmark ?? true;
}

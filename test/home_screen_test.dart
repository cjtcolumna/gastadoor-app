import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/app.dart';

void main() {
  testWidgets(
    'home dashboard shows net worth and setup hint without Supabase',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: GastaDoorApp()));
      await tester.pumpAndSettle();

      expect(find.text('GastaDoor'), findsOneWidget);
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.text('₱0.00'), findsOneWidget);
      expect(find.text('Supabase is not configured'), findsOneWidget);
    },
  );

  testWidgets('add-account form is not covered by the floating tab bar', (
    tester,
  ) async {
    // An iPhone-sized screen.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: GastaDoorApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();

    // A tap in the middle of the save button must land on the button,
    // not on the tab bar drawn over it.
    final button = find.widgetWithText(FilledButton, 'Add account');
    final hits = tester.hitTestOnBinding(tester.getCenter(button));
    final buttonBox = tester.renderObject(button);
    expect(hits.path.any((entry) => entry.target == buttonBox), isTrue);
  });

  testWidgets('floating tab bar switches between Home, Accounts, History', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: GastaDoorApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No expenses yet'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Accounts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No accounts yet'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Net worth'), findsOneWidget);
  });
}

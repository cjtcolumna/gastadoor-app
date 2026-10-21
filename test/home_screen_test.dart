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

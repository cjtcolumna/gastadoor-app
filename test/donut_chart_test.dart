import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/insights/presentation/donut_chart.dart';
import 'package:gastadoor/features/insights/presentation/spending_breakdown_card.dart';
import 'package:gastadoor/features/transactions/domain/spending_breakdown.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

const size = Size(200, 200);

/// A point on the ring at [clock] o'clock (12 = top, 3 = right...).
Offset ringAt(double clock) {
  // The middle of the ring's stroke for a 200px chart.
  const radius = 200 / 2 - 200 * 0.13 / 2 - 5;
  final angle = (clock / 12) * 2 * 3.141592653589793 - 3.141592653589793 / 2;
  return const Offset(100, 100) +
      Offset.fromDirection(angle, radius.toDouble());
}

const food = Category(
  id: 'food',
  userId: 'u',
  name: 'Food',
  kind: TransactionKind.expense,
  icon: 'restaurant',
  color: 'orange',
);
const bills = Category(
  id: 'bills',
  userId: 'u',
  name: 'Bills',
  kind: TransactionKind.expense,
  icon: 'receipt',
  color: 'blue',
);

void main() {
  group('donutSliceAt (which slice a tap lands on)', () {
    // Food 75% (12 to 9 o'clock), Bills 25% (9 to 12 o'clock).
    const values = [75000, 25000];

    test('finds the slice under the finger, going clockwise from the top', () {
      expect(donutSliceAt(ringAt(1), size, values), 0);
      expect(donutSliceAt(ringAt(6), size, values), 0);
      expect(donutSliceAt(ringAt(10), size, values), 1);
    });

    test('the hole in the middle is -1, outside the ring is null', () {
      expect(donutSliceAt(const Offset(100, 100), size, values), -1);
      expect(donutSliceAt(const Offset(2, 2), size, values), isNull);
    });

    test('nothing to tap when there is no spending', () {
      expect(donutSliceAt(ringAt(3), size, const []), isNull);
    });
  });

  group('spending card', () {
    Future<void> pumpCard(WidgetTester tester, List<CategorySlice> slices) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpendingBreakdownCard(
                  slices: slices,
                  categoriesById: const {'food': food, 'bills': bills},
                  chartSize: 200,
                ),
              ),
            ),
          ),
        );

    const slices = [
      CategorySlice(categoryId: 'food', cents: 75000),
      CategorySlice(categoryId: 'bills', cents: 25000),
    ];

    testWidgets('shows the total in the middle of the ring', (tester) async {
      await pumpCard(tester, slices);
      await tester.pumpAndSettle();

      expect(find.byType(DonutChart), findsOneWidget);
      expect(find.text('Total spent'), findsOneWidget);
      expect(find.text('₱1,000.00'), findsOneWidget);
    });

    testWidgets('tapping a slice shows that category, again goes back', (
      tester,
    ) async {
      await pumpCard(tester, slices);
      await tester.pumpAndSettle();
      final chart = tester.getTopLeft(find.byType(DonutChart));

      // Bills is the slice between 9 and 12 o'clock.
      await tester.tapAt(chart + ringAt(10.5));
      await tester.pumpAndSettle();
      expect(find.text('Total spent'), findsNothing);
      expect(find.text('25% of spending'), findsOneWidget);
      expect(find.text('Bills'), findsNWidgets(2)); // middle + its row

      await tester.tapAt(chart + ringAt(10.5));
      await tester.pumpAndSettle();
      expect(find.text('Total spent'), findsOneWidget);
    });

    testWidgets('tapping the middle goes back to the total', (tester) async {
      await pumpCard(tester, slices);
      await tester.pumpAndSettle();
      final chart = tester.getTopLeft(find.byType(DonutChart));

      await tester.tapAt(chart + ringAt(3));
      await tester.pumpAndSettle();
      expect(find.text('75% of spending'), findsOneWidget);

      await tester.tapAt(chart + const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(find.text('Total spent'), findsOneWidget);
    });

    testWidgets('an empty month shows a grey ring and ₱0.00', (tester) async {
      await pumpCard(tester, const []);
      await tester.pumpAndSettle();
      expect(find.text('₱0.00'), findsOneWidget);
      expect(find.text('No spending yet this month.'), findsOneWidget);
    });

    testWidgets('a huge total still fits inside the ring', (tester) async {
      await pumpCard(tester, const [
        CategorySlice(categoryId: 'food', cents: 123456789),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('₱1,234,567.89'), findsWidgets);
    });

    testWidgets('fits the smallest iPhone with double-size text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpCard(tester, slices);
      await tester.pumpAndSettle();
      // Any overflow would be reported as an exception.
      expect(tester.takeException(), isNull);
      expect(find.text('Total spent'), findsOneWidget);
    });
  });
}

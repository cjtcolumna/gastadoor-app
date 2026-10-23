import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/insights/presentation/insights_screen.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/spending_breakdown.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

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
  color: 'amber',
);

Transaction spend(int cents, String? cat, DateTime on) => Transaction(
  id: '$cents$cat${on.month}',
  userId: 'u',
  accountId: 'a',
  categoryId: cat,
  kind: TransactionKind.expense,
  amountCents: cents,
  occurredOn: on,
);

void main() {
  final now = thisMonth();
  final lastMonth = DateTime(now.year, now.month - 1);
  final asked = <DateTime>[];

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    asked.clear();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // This month: Food ₱750 + Bills ₱250. Last month: Food ₱100.
          transactionsInMonthProvider.overrideWith((ref, month) async {
            asked.add(month);
            if (month == now) {
              return [spend(75000, 'food', now), spend(25000, 'bills', now)];
            }
            if (month == lastMonth) return [spend(10000, 'food', lastMonth)];
            return const [];
          }),
          sixMonthTrendProvider.overrideWith(
            (ref) async =>
                monthlyTrend([spend(75000, 'food', now)], lastMonth: now),
          ),
          categoriesProvider.overrideWith((ref) async => [food, bills]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows this month by category with shares', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Total spent'), findsOneWidget);
    expect(find.text('₱1,000.00'), findsWidgets);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('can step back a month but not into the future', (tester) async {
    await pumpScreen(tester);
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );
    expect(next.onPressed, isNull); // already on this month

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(asked, contains(lastMonth));
    expect(find.text('Bills'), findsNothing);
    expect(find.text('100%'), findsOneWidget); // only Food last month
  });

  testWidgets('draws the 6-month income vs spending chart', (tester) async {
    await pumpScreen(tester);
    await tester.scrollUntilVisible(find.byType(BarChart), 300);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Income'), findsWidgets); // legend
    expect(find.text('Spending'), findsOneWidget); // legend
  });
}

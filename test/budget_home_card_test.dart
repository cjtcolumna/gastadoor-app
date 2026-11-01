import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/budgets/data/budget_cycle_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';
import 'package:gastadoor/features/budgets/presentation/budget_home_card.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/categories/presentation/category_pill.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:go_router/go_router.dart';

Category expenseCategory(String id, String name, {int? limit}) => Category(
  id: id,
  userId: 'u',
  name: name,
  kind: TransactionKind.expense,
  icon: 'restaurant',
  color: 'orange',
  budgetCents: limit,
);

Transaction spend(int cents, String? categoryId) => Transaction(
  id: 't$cents',
  userId: 'u',
  accountId: 'cash',
  categoryId: categoryId,
  kind: TransactionKind.expense,
  amountCents: cents,
  occurredOn: DateTime(2026, 10, 5),
);

/// The "Budget" section on Home: one card for all the limits together.
void main() {
  final food = expenseCategory('food', 'Food', limit: 500000);
  final fun = expenseCategory('fun', 'Fun'); // no limit
  final transport = expenseCategory('transport', 'Transport', limit: 500000);

  // Still running for a very long time, so "days left" always shows.
  final longPeriod = BudgetPeriod(
    start: DateTime(2026, 10, 1),
    end: DateTime(2999, 12, 31),
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    List<Category>? categories,
    List<Transaction> month = const [],
    BudgetPeriod? period,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: BudgetHomeSection()),
          ),
        ),
        GoRoute(path: '/budget', builder: (_, _) => const Text('Budget page')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref) async => categories ?? [food, fun, transport],
          ),
          monthTransactionsProvider.overrideWith((ref) async => month),
          currentPeriodProvider.overrideWith(
            (ref) async => period ?? longPeriod,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BudgetRing ring(WidgetTester tester) =>
      tester.widget<BudgetRing>(find.byType(BudgetRing));
  AppColors colors(WidgetTester tester) =>
      tester.element(find.byType(BudgetHomeSection)).appColors;

  testWidgets('shows one card: percent, what is left, spent of total', (
    tester,
  ) async {
    await pumpHome(
      tester,
      month: [
        spend(376000, 'food'),
        spend(100000, 'transport'),
        spend(120000, 'fun'), // no limit: not counted
      ],
    );
    expect(find.text('Budget'), findsOneWidget); // the heading
    expect(find.text('47%'), findsOneWidget); // 4,760 of 10,000, rounded down
    expect(find.text('₱5,240.00 left'), findsOneWidget);
    expect(find.text('₱4,760.00 of ₱10,000.00'), findsOneWidget);
    expect(find.textContaining('days left'), findsOneWidget);

    final r = ring(tester);
    expect(r.progress, closeTo(0.476, 0.0001));
    expect(r.color, colors(tester).income);
  });

  testWidgets('no categories are listed on Home any more', (tester) async {
    await pumpHome(tester, month: [spend(376000, 'food')]);
    expect(find.text('Food'), findsNothing);
    expect(find.text('Transport'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the ring turns amber at 75%', (tester) async {
    await pumpHome(
      tester,
      month: [spend(400000, 'food'), spend(400000, 'transport')],
    );
    expect(find.text('80%'), findsOneWidget);
    expect(ring(tester).color, colors(tester).warning);
  });

  testWidgets('just under 75% is still green and says 74%', (tester) async {
    await pumpHome(tester, month: [spend(749900, 'food')]);
    expect(find.text('74%'), findsOneWidget);
    expect(ring(tester).color, colors(tester).income);
  });

  testWidgets('over the limits: full red ring and "over"', (tester) async {
    await pumpHome(
      tester,
      month: [spend(700000, 'food'), spend(480000, 'transport')],
    ); // 11,800 of 10,000
    expect(find.text('118%'), findsOneWidget);
    expect(find.text('₱1,800.00 over'), findsOneWidget);
    expect(find.text('₱0.00 left'), findsNothing); // "over", not "left"
    final r = ring(tester);
    expect(r.progress, 1.0);
    expect(r.color, colors(tester).expense);
  });

  testWidgets('no "days left" for the open salary period', (tester) async {
    await pumpHome(
      tester,
      period: BudgetPeriod(
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 10, 20),
        isOpen: true,
      ),
    );
    expect(find.byType(BudgetRing), findsOneWidget);
    expect(find.textContaining('days left'), findsNothing);
  });

  testWidgets('with no limits yet, a hint and a button replace the ring', (
    tester,
  ) async {
    await pumpHome(tester, categories: [expenseCategory('food', 'Food')]);
    expect(find.byType(BudgetRing), findsNothing);
    expect(find.textContaining('Set a monthly limit'), findsOneWidget);

    await tester.tap(find.text('Set a limit'));
    await tester.pumpAndSettle();
    expect(find.text('Budget page'), findsOneWidget);
  });

  testWidgets('tapping the card opens the Budget page', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byType(BudgetRing));
    await tester.pumpAndSettle();
    expect(find.text('Budget page'), findsOneWidget);
  });

  testWidgets('the Manage link opens the Budget page', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Budget page'), findsOneWidget);
  });

  testWidgets('fits on a narrow phone, even with huge amounts', (tester) async {
    await pumpHome(
      tester,
      width: 320,
      month: [spend(123456789, 'food'), spend(48000000, 'transport')],
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(BudgetRing), findsOneWidget);
  });
}

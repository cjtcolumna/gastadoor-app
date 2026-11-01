import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/budgets/data/budget_cycle_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';
import 'package:gastadoor/features/budgets/presentation/budget_screen.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

/// Remembers the cycle that was saved instead of calling Supabase.
class FakeCycle extends BudgetCycleNotifier {
  final saved = <BudgetCycle>[];

  @override
  Future<BudgetCycle> build() async => BudgetCycle.calendarMonth;

  @override
  Future<void> save(BudgetCycle cycle) async {
    saved.add(cycle);
    state = AsyncData(cycle);
  }
}

/// The "Budget cycle" row on the Budget page and its form.
void main() {
  late FakeCycle cycle;

  Future<void> pumpBudgets(
    WidgetTester tester, {
    List<DateTime> salaryDates = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    cycle = FakeCycle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthTransactionsProvider.overrideWith(
            (ref) async => const <Transaction>[],
          ),
          categoriesProvider.overrideWith((ref) async => const []),
          budgetCycleProvider.overrideWith(() => cycle),
          salaryDatesProvider.overrideWith((ref) async => salaryDates),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const BudgetScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Budget cycle shows the current choice', (tester) async {
    await pumpBudgets(tester);
    expect(find.text('Budget cycle'), findsOneWidget);
    expect(find.text('Monthly · 1st'), findsOneWidget);
  });

  testWidgets('Budget cycle can be changed to twice a month', (tester) async {
    await pumpBudgets(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    // Monthly: only one day to pick.
    expect(find.text('Second period starts on'), findsNothing);

    await tester.tap(find.text('Twice a month'));
    await tester.pumpAndSettle();
    expect(find.text('Second period starts on'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(cycle.saved, [
      const BudgetCycle(
        type: BudgetCycleType.twiceMonthly,
        firstDay: 1,
        secondDay: 15,
      ),
    ]);
    expect(find.text('Budget cycle saved.'), findsOneWidget);
    // The row now describes the new cycle.
    expect(find.text('Twice a month · 1st & 15th'), findsOneWidget);
  });

  testWidgets('On salary has no days to pick, and explains the fallback', (
    tester,
  ) async {
    await pumpBudgets(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On salary'));
    await tester.pumpAndSettle();

    expect(find.text('A new period starts on'), findsNothing);
    expect(find.text('Second period starts on'), findsNothing);
    expect(find.textContaining('not logged a salary yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(cycle.saved.single.type, BudgetCycleType.salary);
    expect(find.text('When I log my salary'), findsOneWidget);
  });

  testWidgets('On salary shows when the current round started', (tester) async {
    final now = DateTime.now();
    await pumpBudgets(
      tester,
      salaryDates: [DateTime(now.year, now.month, now.day)],
    );
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On salary'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Right now: Since '), findsOneWidget);
    expect(find.textContaining('not logged a salary yet'), findsNothing);
  });

  testWidgets('twice a month needs two different days', (tester) async {
    await pumpBudgets(tester);
    await tester.tap(find.text('Budget cycle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Twice a month'));
    await tester.pumpAndSettle();

    // Make the first day the 15th too (the second is the 15th already).
    await tester.tap(find.text('1st').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15th').last);
    await tester.pumpAndSettle();

    expect(find.text('Pick two different days.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });
}

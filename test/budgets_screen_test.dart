import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/budgets/data/budgets_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget.dart';
import 'package:gastadoor/features/budgets/presentation/budgets_screen.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';

/// Keeps budgets in memory instead of Supabase.
class FakeBudgetsNotifier extends BudgetsNotifier {
  FakeBudgetsNotifier(this.start);

  final List<Budget> start;
  final added = <(String?, String, int)>[];
  final saved = <Budget>[];
  final removed = <String>[];

  @override
  Future<List<Budget>> build() async => start;

  @override
  Future<void> add({
    required String? categoryId,
    required String name,
    required int amountCents,
  }) async => added.add((categoryId, name, amountCents));

  @override
  Future<void> save(Budget budget) async => saved.add(budget);

  @override
  Future<void> remove(String id) async => removed.add(id);
}

const food = Category(
  id: 'food',
  userId: 'u',
  name: 'Food',
  kind: TransactionKind.expense,
  icon: 'restaurant',
  color: 'orange',
);
const transport = Category(
  id: 'transport',
  userId: 'u',
  name: 'Transport',
  kind: TransactionKind.expense,
  icon: 'bus',
  color: 'blue',
);

Budget budget(String id, String? categoryId, int limit) => Budget(
  id: id,
  userId: 'u',
  categoryId: categoryId,
  name: categoryId ?? 'All spending',
  amountCents: limit,
  startsOn: DateTime(2026, 10, 1),
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

void main() {
  late FakeBudgetsNotifier fake;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Budget> budgets = const [],
    List<Transaction> month = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    fake = FakeBudgetsNotifier(budgets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          budgetsProvider.overrideWith(() => fake),
          monthTransactionsProvider.overrideWith((ref) async => month),
          categoriesProvider.overrideWith((ref) async => [food, transport]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BudgetsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  testWidgets('shows spent, limit, and what is left', (tester) async {
    await pumpScreen(
      tester,
      budgets: [budget('b1', 'food', 500000)],
      month: [spend(376000, 'food'), spend(99900, 'transport')],
    );

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('₱3,760.00 of ₱5,000.00'), findsOneWidget);
    expect(find.text('₱1,240.00 left'), findsOneWidget);
  });

  testWidgets('shows how much you are over', (tester) async {
    await pumpScreen(
      tester,
      budgets: [budget('b1', 'food', 100000)],
      month: [spend(132000, 'food')],
    );
    expect(find.text('₱320.00 over'), findsOneWidget);
  });

  testWidgets('All spending is listed first', (tester) async {
    await pumpScreen(
      tester,
      budgets: [budget('b1', 'food', 500000), budget('b2', null, 2000000)],
    );
    final top = tester.getTopLeft(find.text('All spending')).dy;
    final foodTop = tester.getTopLeft(find.text('Food')).dy;
    expect(top, lessThan(foodTop));
  });

  testWidgets('adding asks what the budget is for', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('Set a monthly limit'), findsOneWidget);

    await tester.tap(find.byTooltip('Add budget'));
    await tester.pumpAndSettle();
    expect(find.text('New monthly budget'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '5,000');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(find.text('Choose what this budget is for.'), findsOneWidget);
    expect(fake.added, isEmpty);

    await tester.tap(chip('Food'));
    await tester.pumpAndSettle();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(fake.added, [('food', 'Food', 500000)]);
  });

  testWidgets('categories that already have a budget are hidden', (
    tester,
  ) async {
    await pumpScreen(tester, budgets: [budget('b1', 'food', 500000)]);
    await tester.tap(find.byTooltip('Add budget'));
    await tester.pumpAndSettle();

    expect(chip('Food'), findsNothing);
    expect(chip('Transport'), findsOneWidget);
    expect(chip('All spending'), findsOneWidget);
  });

  testWidgets('tap a budget to change or delete it', (tester) async {
    await pumpScreen(tester, budgets: [budget('b1', 'food', 500000)]);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Edit budget'), findsOneWidget);
    expect(find.text('5000.00'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '6000');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(fake.saved.single.amountCents, 600000);
    expect(fake.saved.single.categoryId, 'food');

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete budget'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(fake.removed, ['b1']);
  });

  testWidgets('a budget for an archived category keeps its name', (
    tester,
  ) async {
    // 'coffee' isn't in the active categories (it was archived).
    final coffee = budget('b1', 'coffee', 100000).copyWith(name: 'Coffee');
    await pumpScreen(tester, budgets: [coffee]);

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('All spending'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/budgets/data/budget_cycle_provider.dart';
import 'package:gastadoor/features/budgets/domain/budget_cycle.dart';
import 'package:gastadoor/features/budgets/presentation/budget_screen.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/categories/presentation/category_form_sheet.dart';
import 'package:gastadoor/features/categories/presentation/category_pill.dart';
import 'package:gastadoor/features/transactions/data/transactions_repository.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/presentation/kind_switch.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Records what the screen asked for instead of calling Supabase.
class FakeCategoryActions implements CategoryActions {
  final added = <(String, TransactionKind, String, String, int?)>[];
  final saved = <Category>[];
  final archived = <String>[];
  final restored = <String>[];
  Object? failWith;

  @override
  Future<void> add({
    required String name,
    required TransactionKind kind,
    required String icon,
    required String color,
    int? budgetCents,
  }) async {
    if (failWith != null) throw failWith!;
    added.add((name, kind, icon, color, budgetCents));
  }

  @override
  Future<void> save(Category category) async => saved.add(category);

  @override
  Future<void> archive(String id) async => archived.add(id);

  @override
  Future<void> restore(String id) async => restored.add(id);
}

Category expenseCategory(
  String id,
  String name, {
  int? limit,
  bool archived = false,
  String icon = 'restaurant',
}) => Category(
  id: id,
  userId: 'u',
  name: name,
  kind: TransactionKind.expense,
  icon: icon,
  color: 'orange',
  budgetCents: limit,
  archived: archived,
);

Category incomeCategory(
  String id,
  String name, {
  bool isSalary = false,
  bool archived = false,
}) => Category(
  id: id,
  userId: 'u',
  name: name,
  kind: TransactionKind.income,
  icon: 'work',
  color: 'green',
  isSalary: isSalary,
  archived: archived,
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
  late FakeCategoryActions actions;

  // As the app loads them: active categories, sorted by name.
  final food = expenseCategory('food', 'Food', limit: 500000);
  final fun = expenseCategory('fun', 'Fun'); // no limit
  final gift = incomeCategory('gift', 'Gift');
  final salary = incomeCategory('salary', 'Salary', isSalary: true);
  final transport = expenseCategory('transport', 'Transport', limit: 500000);
  final everyone = [food, fun, gift, salary, transport];

  // A period that is still running for a very long time, so "days left"
  // always shows, whatever day the tests run on.
  final longPeriod = BudgetPeriod(
    start: DateTime(2026, 10, 1),
    end: DateTime(2999, 12, 31),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Category>? categories,
    List<Category> archived = const [],
    List<Transaction> month = const [],
    BudgetPeriod? period,
    double width = 390,
  }) async {
    // Tall, so the whole page is built (a ListView only builds what's near
    // the screen).
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    actions = FakeCategoryActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (ref) async => categories ?? everyone,
          ),
          archivedCategoriesProvider.overrideWith((ref) async => archived),
          monthTransactionsProvider.overrideWith((ref) async => month),
          currentPeriodProvider.overrideWith(
            (ref) async => period ?? longPeriod,
          ),
          categoryActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const BudgetScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> showIncome(WidgetTester tester) async {
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
  }

  Finder save() => find.widgetWithText(FilledButton, 'Save');
  Finder nameField() => find.widgetWithText(TextFormField, 'Name');
  Finder limitField() =>
      find.widgetWithText(TextFormField, 'Monthly limit (optional)');
  Finder inForm(Finder finder) =>
      find.descendant(of: find.byType(CategoryFormSheet), matching: finder);
  double top(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;
  AppColors colors(WidgetTester tester) =>
      tester.element(find.byType(BudgetScreen)).appColors;

  group('Expenses', () {
    testWidgets('starts on Expenses, with a ring and the categories', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Budget'), findsOneWidget); // the title
      expect(find.byType(BudgetRing), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Fun'), findsOneWidget);
      // Income categories live on the other side of the switch.
      expect(find.text('Salary'), findsNothing);
      expect(find.text('Gift'), findsNothing);
    });

    testWidgets('the ring adds up every limit and what was spent', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        month: [
          spend(376000, 'food'),
          spend(100000, 'transport'),
          spend(120000, 'fun'), // no limit: not in the ring
        ],
      );
      // Spent 3,760 + 1,000 = 4,760 of 5,000 + 5,000 = 10,000.
      expect(find.text('₱4,760.00'), findsOneWidget);
      expect(find.text('of ₱10,000.00'), findsOneWidget);
      expect(find.text('₱5,240.00 left'), findsOneWidget);
      expect(find.text('₱1,200.00 spent outside your limits'), findsOneWidget);

      final ring = tester.widget<BudgetRing>(find.byType(BudgetRing));
      expect(ring.progress, closeTo(0.476, 0.0001));
      expect(ring.color, colors(tester).income); // under 75%
    });

    testWidgets('says how many days are left in the period', (tester) async {
      await pumpScreen(tester);
      expect(find.textContaining('days left'), findsOneWidget);
    });

    testWidgets('no "days left" for the open salary period', (tester) async {
      await pumpScreen(
        tester,
        period: BudgetPeriod(
          start: DateTime(2026, 10, 15),
          end: DateTime(2026, 10, 20),
          isOpen: true,
        ),
      );
      expect(find.byType(BudgetRing), findsOneWidget);
      expect(find.textContaining('days left'), findsNothing);
      expect(find.textContaining('since Oct 15'), findsOneWidget);
    });

    testWidgets('the ring turns amber at 75%', (tester) async {
      await pumpScreen(
        tester,
        month: [spend(400000, 'food'), spend(400000, 'transport')],
      ); // 8,000 of 10,000
      expect(
        tester.widget<BudgetRing>(find.byType(BudgetRing)).color,
        colors(tester).warning,
      );
    });

    testWidgets('the ring is full and red once over', (tester) async {
      await pumpScreen(
        tester,
        month: [spend(700000, 'food'), spend(480000, 'transport')],
      ); // 11,800 of 10,000
      final ring = tester.widget<BudgetRing>(find.byType(BudgetRing));
      expect(ring.color, colors(tester).expense);
      expect(ring.progress, 1.0);
      expect(find.text('₱1,800.00 over'), findsOneWidget);
    });

    testWidgets('each category shows spent, limit, and what is left', (
      tester,
    ) async {
      await pumpScreen(tester, month: [spend(376000, 'food')]);
      expect(find.text('₱3,760.00 of ₱5,000.00'), findsOneWidget);
      expect(find.text('₱1,240.00 left'), findsOneWidget);
    });

    testWidgets('a category over its limit says by how much', (tester) async {
      await pumpScreen(tester, month: [spend(632000, 'food')]);
      expect(find.text('₱1,320.00 over'), findsOneWidget);
    });

    testWidgets('categories with a limit come first, then "No limit"', (
      tester,
    ) async {
      await pumpScreen(tester, month: [spend(100000, 'transport')]);
      expect(find.text('No limit'), findsOneWidget); // only Fun
      // Transport is the most used, Food next, and Fun (no limit) last,
      // even though it comes before Transport by name.
      expect(
        top(tester, find.text('Transport')),
        lessThan(top(tester, find.text('Food'))),
      );
      expect(
        top(tester, find.text('Food')),
        lessThan(top(tester, find.text('Fun'))),
      );
    });

    testWidgets('with no limits yet, a hint replaces the ring', (tester) async {
      await pumpScreen(
        tester,
        categories: [expenseCategory('food', 'Food'), gift, salary],
      );
      expect(find.textContaining('No limits yet'), findsOneWidget);
      expect(find.byType(BudgetRing), findsNothing);
      expect(find.text('No limit'), findsOneWidget);
    });

    testWidgets('the budget cycle row is here, with the current choice', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Budget cycle'), findsOneWidget);
      expect(find.text('Monthly · 1st'), findsOneWidget);
    });

    testWidgets('archived expense categories are listed and can be restored', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        archived: [
          expenseCategory('pets', 'Pets', archived: true),
          incomeCategory('old', 'Old job', archived: true),
        ],
      );
      // Only the expense one is counted on this side.
      await tapVisible(tester, find.text('Archived (1)'));
      expect(find.text('Pets'), findsOneWidget);
      expect(find.text('Old job'), findsNothing);

      await tapVisible(tester, find.text('Restore'));
      expect(actions.restored, ['pets']);
    });
  });

  group('on a narrow phone', () {
    // The test font is very wide, so anything that would not fit on a small
    // screen overflows here (and Flutter fails the test).
    testWidgets('Expenses fits, even over budget with long numbers', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        width: 320,
        month: [
          spend(123456789, 'food'),
          spend(48000000, 'transport'),
          spend(5000000, 'fun'),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BudgetRing), findsOneWidget);
    });

    testWidgets('Income fits', (tester) async {
      await pumpScreen(tester, width: 320);
      await showIncome(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Used for your budget cycle'), findsOneWidget);
    });
  });

  group('Income', () {
    testWidgets('is a plain list: no ring, no limits, no cycle row', (
      tester,
    ) async {
      await pumpScreen(tester);
      await showIncome(tester);

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Gift'), findsOneWidget);
      expect(find.text('Food'), findsNothing);

      expect(find.byType(BudgetRing), findsNothing);
      expect(find.text('No limit'), findsNothing);
      expect(find.textContaining('days left'), findsNothing);
      expect(find.textContaining('left'), findsNothing);
      expect(find.text('Budget cycle'), findsNothing);
      expect(find.text('Categories'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Salary comes first and says why it is special', (
      tester,
    ) async {
      await pumpScreen(tester);
      await showIncome(tester);

      // "Gift" comes before "Salary" by name, but Salary is listed first.
      expect(
        top(tester, find.text('Salary')),
        lessThan(top(tester, find.text('Gift'))),
      );
      expect(find.text('Used for your budget cycle'), findsOneWidget);
    });

    testWidgets('has its own empty message', (tester) async {
      await pumpScreen(tester, categories: [food]);
      await showIncome(tester);
      expect(find.text('No income categories yet.'), findsOneWidget);
    });

    testWidgets('shows only archived income categories', (tester) async {
      await pumpScreen(
        tester,
        archived: [
          expenseCategory('pets', 'Pets', archived: true),
          incomeCategory('old', 'Old job', archived: true),
        ],
      );
      await showIncome(tester);
      await tapVisible(tester, find.text('Archived (1)'));
      expect(find.text('Old job'), findsOneWidget);
      expect(find.text('Pets'), findsNothing);
    });

    testWidgets('can switch back to Expenses', (tester) async {
      await pumpScreen(tester);
      await showIncome(tester);
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetRing), findsOneWidget);
    });
  });

  group('the + button adds to the side you are on', () {
    testWidgets('Expenses', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('New expense category'), findsOneWidget);
    });

    testWidgets('Income', (tester) async {
      await pumpScreen(tester);
      await showIncome(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('New income category'), findsOneWidget);
      // Income has no limit.
      expect(limitField(), findsNothing);
    });
  });

  group('the limit in the category form', () {
    testWidgets('shows the saved limit and saves a new one', (tester) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Food'));
      expect(find.text('Edit category'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(limitField()).controller!.text,
        '5000.00',
      );

      await tester.enterText(limitField(), '6,000');
      await tapVisible(tester, save());

      final c = actions.saved.single;
      expect(c.id, 'food');
      expect(c.budgetCents, 600000);
    });

    testWidgets('emptying the box removes the limit', (tester) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Food'));
      await tester.enterText(limitField(), '');
      await tapVisible(tester, save());
      expect(actions.saved.single.budgetCents, isNull);
    });

    testWidgets('a category with no limit starts with an empty box', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Fun'));
      expect(tester.widget<TextFormField>(limitField()).controller!.text, '');
      await tapVisible(tester, save());
      expect(actions.saved.single.budgetCents, isNull);
    });

    testWidgets('a limit can be added to a category that had none', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Fun'));
      await tester.enterText(limitField(), '1500.50');
      await tapVisible(tester, save());
      expect(actions.saved.single.budgetCents, 150050);
    });

    testWidgets('zero is not a limit', (tester) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Food'));
      await tester.enterText(limitField(), '0');
      await tapVisible(tester, save());
      expect(find.text('Enter an amount above zero'), findsOneWidget);
      expect(actions.saved, isEmpty);
    });

    testWidgets('a new category can start with a limit', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();

      await tester.enterText(nameField(), 'Coffee');
      await tester.enterText(limitField(), '1,500');
      await tapVisible(tester, save());

      expect(actions.added, [
        ('Coffee', TransactionKind.expense, 'category', 'blue', 150000),
      ]);
    });

    testWidgets('a new category can have no limit', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();

      await tester.enterText(nameField(), 'Coffee');
      await tapVisible(tester, save());
      expect(actions.added.single.$5, isNull);
    });

    testWidgets('choosing Income in the form hides the limit', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      expect(limitField(), findsOneWidget);

      await tester.tap(inForm(find.text('Income')));
      await tester.pumpAndSettle();
      expect(limitField(), findsNothing);

      // Even if a limit was typed before switching, income saves without it.
      await tester.tap(inForm(find.text('Expense')));
      await tester.pumpAndSettle();
      await tester.enterText(limitField(), '900');
      await tester.tap(inForm(find.text('Income')));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Bonus');
      await tapVisible(tester, save());
      expect(actions.added.single.$2, TransactionKind.income);
      expect(actions.added.single.$5, isNull);
    });

    testWidgets('editing an income category has no limit box', (tester) async {
      await pumpScreen(tester);
      await showIncome(tester);
      await tapVisible(tester, find.text('Gift'));
      expect(find.text('Edit category'), findsOneWidget);
      expect(limitField(), findsNothing);
    });
  });

  group('editing and archiving', () {
    testWidgets('adds a category with a chosen icon and color', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('New expense category'), findsOneWidget);

      // A name is required.
      await tapVisible(tester, save());
      expect(find.text('Enter a name'), findsOneWidget);

      await tester.enterText(nameField(), '  Coffee ');
      await tapVisible(tester, find.bySemanticsLabel('cafe'));
      await tapVisible(tester, find.bySemanticsLabel('brown'));
      await tapVisible(tester, save());

      expect(actions.added, [
        ('Coffee', TransactionKind.expense, 'cafe', 'brown', null),
      ]);
    });

    testWidgets('editing keeps the kind and saves name, icon, color', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Food'));
      expect(find.text('Edit category'), findsOneWidget);
      // Kind can't change once a category exists.
      expect(inForm(find.byType(KindSwitch)), findsNothing);

      await tester.enterText(nameField(), 'Meals');
      await tapVisible(tester, find.bySemanticsLabel('fitness'));
      await tapVisible(tester, save());

      final c = actions.saved.single;
      expect(c.id, 'food');
      expect(c.name, 'Meals');
      expect(c.icon, 'fitness');
      expect(c.color, 'orange'); // unchanged
      expect(c.kind, TransactionKind.expense);
      expect(c.budgetCents, 500000); // the limit is untouched
    });

    testWidgets('a category with the old shopping bag edits as the cart', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        categories: [expenseCategory('shop', 'Shopping', icon: 'shopping')],
      );
      await tapVisible(tester, find.text('Shopping'));
      await tapVisible(tester, save());
      // Saving moves it to the cart's name, so the old one fades away.
      expect(actions.saved.single.icon, 'groceries');
    });

    testWidgets('archiving asks first', (tester) async {
      await pumpScreen(tester);
      await tapVisible(tester, find.text('Food'));
      await tapVisible(tester, find.text('Archive category'));
      expect(find.text('Archive Food?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(actions.archived, ['food']);
    });

    testWidgets('Salary is needed, so it cannot be archived', (tester) async {
      await pumpScreen(tester);
      await showIncome(tester);
      await tapVisible(tester, find.text('Salary'));
      expect(find.text('Edit category'), findsOneWidget);
      expect(find.text('Archive category'), findsNothing);
      expect(
        find.textContaining('Needed for your budget cycle'),
        findsOneWidget,
      );

      // It can still be renamed, and it stays the salary category.
      await tester.enterText(nameField(), 'Sweldo');
      await tapVisible(tester, save());
      final c = actions.saved.single;
      expect(c.name, 'Sweldo');
      expect(c.isSalary, isTrue);
    });

    testWidgets('a duplicate name shows a friendly message', (tester) async {
      await pumpScreen(tester);
      actions.failWith = const PostgrestException(
        message: 'duplicate key value',
        code: '23505',
      );
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(nameField(), 'Food');
      await tapVisible(tester, save());

      expect(
        find.textContaining('You already have a category called "Food"'),
        findsOneWidget,
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/categories/presentation/categories_screen.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Records what the screen asked for instead of calling Supabase.
class FakeCategoryActions implements CategoryActions {
  final added = <(String, TransactionKind, String, String)>[];
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
  }) async {
    if (failWith != null) throw failWith!;
    added.add((name, kind, icon, color));
  }

  @override
  Future<void> save(Category category) async => saved.add(category);

  @override
  Future<void> archive(String id) async => archived.add(id);

  @override
  Future<void> restore(String id) async => restored.add(id);
}

const food = Category(
  id: 'food',
  userId: 'u',
  name: 'Food',
  kind: TransactionKind.expense,
  icon: 'restaurant',
  color: 'orange',
);
const salary = Category(
  id: 'salary',
  userId: 'u',
  name: 'Salary',
  kind: TransactionKind.income,
  icon: 'work',
  color: 'green',
);
const oldPets = Category(
  id: 'pets',
  userId: 'u',
  name: 'Pets',
  kind: TransactionKind.expense,
  icon: 'pets',
  color: 'brown',
  archived: true,
);

void main() {
  late FakeCategoryActions actions;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Category> archived = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    actions = FakeCategoryActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) async => [food, salary]),
          archivedCategoriesProvider.overrideWith((ref) async => archived),
          categoryActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CategoriesScreen(),
        ),
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

  Finder save() => find.widgetWithText(FilledButton, 'Save');
  Finder nameField() => find.widgetWithText(TextFormField, 'Name');

  testWidgets('lists expense and income categories', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
  });

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
      ('Coffee', TransactionKind.expense, 'cafe', 'brown'),
    ]);
  });

  testWidgets('the Income section adds income categories', (tester) async {
    await pumpScreen(tester);
    // The second "Add" link belongs to the Income section.
    await tapVisible(tester, find.widgetWithText(TextButton, 'Add').last);
    expect(find.text('New income category'), findsOneWidget);
  });

  testWidgets('editing keeps the kind and saves name, icon, color', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tapVisible(tester, find.text('Food'));
    expect(find.text('Edit category'), findsOneWidget);
    // Kind can't change once a category exists.
    expect(find.byType(SegmentedButton<TransactionKind>), findsNothing);

    await tester.enterText(nameField(), 'Meals');
    await tapVisible(tester, find.bySemanticsLabel('groceries'));
    await tapVisible(tester, save());

    final c = actions.saved.single;
    expect(c.id, 'food');
    expect(c.name, 'Meals');
    expect(c.icon, 'groceries');
    expect(c.color, 'orange'); // unchanged
    expect(c.kind, TransactionKind.expense);
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

  testWidgets('archived categories can be restored', (tester) async {
    await pumpScreen(tester, archived: [oldPets]);
    await tapVisible(tester, find.text('Archived (1)'));
    await tapVisible(tester, find.text('Restore'));
    expect(actions.restored, ['pets']);
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
}

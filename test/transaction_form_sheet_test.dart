import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/utils/dates.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/transactions/data/transaction_actions.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';
import 'package:gastadoor/features/transactions/presentation/transaction_form_sheet.dart';

class FakeAccountsNotifier extends AccountsNotifier {
  @override
  Future<List<Account>> build() async => const [
    Account(id: 'cash', userId: 'u', name: 'Cash', type: AccountType.cash),
    Account(id: 'gcash', userId: 'u', name: 'GCash', type: AccountType.eWallet),
  ];
}

/// Records what the form asked to save instead of calling Supabase.
class FakeActions implements TransactionActions {
  final added = <TransactionDraft>[];
  final updated = <(String, TransactionDraft)>[];
  final deleted = <String>[];

  @override
  Future<void> add(TransactionDraft draft) async => added.add(draft);

  @override
  Future<void> update(String id, TransactionDraft draft) async =>
      updated.add((id, draft));

  @override
  Future<void> delete(String id) async => deleted.add(id);
}

const categories = [
  Category(
    id: 'food',
    userId: 'u',
    name: 'Food',
    kind: TransactionKind.expense,
    icon: 'restaurant',
    color: 'orange',
  ),
  Category(
    id: 'salary',
    userId: 'u',
    name: 'Salary',
    kind: TransactionKind.income,
    icon: 'work',
    color: 'green',
  ),
];

void main() {
  late FakeActions actions;

  /// Shows a button that opens the sheet, like the real "+" button does.
  Future<void> openSheet(WidgetTester tester, {Transaction? existing}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    actions = FakeActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(FakeAccountsNotifier.new),
          categoriesProvider.overrideWith((ref) async => categories),
          archivedAccountsProvider.overrideWith(
            (ref) async => const [
              Account(
                id: 'old',
                userId: 'u',
                name: 'Old Wallet',
                type: AccountType.eWallet,
                archived: true,
              ),
            ],
          ),
          transactionActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showTransactionFormSheet(context, existing: existing),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.byType(TextFormField).first;
  Finder save() => find.widgetWithText(FilledButton, 'Save');

  testWidgets('needs an amount above zero', (tester) async {
    await openSheet(tester);

    await tapVisible(tester, save());
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(amountField(), '0');
    await tapVisible(tester, save());
    expect(find.text('Enter an amount above zero'), findsOneWidget);
    expect(actions.added, isEmpty);
  });

  testWidgets('saves an expense with category, account, and note', (
    tester,
  ) async {
    await openSheet(tester);
    expect(find.text('New expense'), findsOneWidget);

    await tester.enterText(amountField(), '189.50');
    await tapVisible(tester, find.text('Food'));
    await tapVisible(tester, find.text('GCash'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note (optional)'),
      'Jollibee',
    );
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.kind, TransactionKind.expense);
    expect(draft.amountCents, 18950);
    expect(draft.categoryId, 'food');
    expect(draft.accountId, 'gcash');
    expect(draft.occurredOn, dateOnly(DateTime.now()));
    expect(draft.note, 'Jollibee');
    expect(find.text('New expense'), findsNothing); // sheet closed
  });

  testWidgets('uses the first account when none is picked', (tester) async {
    await openSheet(tester);
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    expect(actions.added.single.accountId, 'cash');
    expect(actions.added.single.categoryId, isNull);
  });

  testWidgets('switching to Income shows income categories', (tester) async {
    await openSheet(tester);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);

    await tapVisible(tester, find.text('Income'));
    expect(find.text('New income'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  final existing = Transaction(
    id: 'txn-1',
    userId: 'u',
    accountId: 'gcash',
    categoryId: 'food',
    kind: TransactionKind.expense,
    amountCents: 24500,
    occurredOn: DateTime(2026, 10, 1),
    note: 'Grab',
  );

  testWidgets('edits an existing expense', (tester) async {
    await openSheet(tester, existing: existing);
    expect(find.text('Edit expense'), findsOneWidget);
    expect(find.text('245.00'), findsOneWidget);
    expect(find.text('Oct 1, 2026'), findsOneWidget);

    await tester.enterText(amountField(), '250');
    await tapVisible(tester, save());

    final (id, draft) = actions.updated.single;
    expect(id, 'txn-1');
    expect(draft.amountCents, 25000);
    expect(draft.accountId, 'gcash');
  });

  testWidgets('editing shows the archived account it came from', (
    tester,
  ) async {
    final fromOldWallet = existing.copyWith(accountId: 'old');
    await openSheet(tester, existing: fromOldWallet);

    expect(find.text('Old Wallet (archived)'), findsOneWidget);
    // Saving keeps it on the archived account.
    await tapVisible(tester, save());
    expect(actions.updated.single.$2.accountId, 'old');
  });

  testWidgets('deletes only after confirming', (tester) async {
    await openSheet(tester, existing: existing);

    await tapVisible(tester, find.text('Delete expense'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(actions.deleted, isEmpty);

    await tapVisible(tester, find.text('Delete expense'));
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(actions.deleted, ['txn-1']);
  });
}

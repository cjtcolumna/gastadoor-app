import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chip_helpers.dart';

import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/core/utils/dates.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/categories/data/categories_repository.dart';
import 'package:gastadoor/features/categories/domain/category.dart';
import 'package:gastadoor/features/transactions/data/transaction_actions.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';
import 'package:gastadoor/features/transactions/presentation/transaction_form_sheet.dart';

const cashAccount = Account(
  id: 'cash',
  userId: 'u',
  name: 'Cash',
  type: AccountType.cash,
);
const gcashAccount = Account(
  id: 'gcash',
  userId: 'u',
  name: 'GCash',
  type: AccountType.eWallet,
);

class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier([this.accounts = const [cashAccount, gcashAccount]]);

  final List<Account> accounts;

  @override
  Future<List<Account>> build() async => accounts;
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
  Future<void> openSheet(
    WidgetTester tester, {
    Transaction? existing,
    List<Account> accounts = const [cashAccount, gcashAccount],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    actions = FakeActions();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => FakeAccountsNotifier(accounts)),
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
          theme: AppTheme.light(), // the real app theme
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

  testWidgets('selected switch and chips keep their rounded icons', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Income'));
    await tapVisible(tester, find.text('Salary'));
    await tapVisible(tester, find.text('GCash'));

    // No check marks replace the icons when something is selected.
    // (Chips paint their check mark directly, so we check the setting.)
    expect(checkmarksShown(tester, find.text('GCash')), isFalse);
    expect(checkmarksShown(tester, find.text('Salary')), isFalse);
    final kindSwitch = tester.widget<SegmentedButton<TransactionKind>>(
      find.byType(SegmentedButton<TransactionKind>),
    );
    expect(kindSwitch.showSelectedIcon, isFalse);
    // The Income arrow, Salary icon, and GCash's own icon are all shown.
    expect(find.byIcon(Icons.south_west_rounded), findsOneWidget);
    expect(find.byIcon(Icons.work_rounded), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/banks/gcash.png')),
      findsOneWidget,
    );
  });

  testWidgets('a transfer moves money from one account to another', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Transfer'));

    expect(find.text('New transfer'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Category'), findsNothing); // transfers have none

    await tester.enterText(amountField(), '1,000');
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.kind, TransactionKind.transfer);
    expect(draft.amountCents, 100000);
    expect(draft.accountId, 'cash'); // From: first account
    expect(draft.toAccountId, 'gcash'); // To: the other one
    expect(draft.toRow()['category_id'], isNull);
  });

  testWidgets('the To list never offers the From account', (tester) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Transfer'));
    // Pick GCash as From: To must switch to Cash automatically.
    await tapVisible(tester, find.text('GCash').first);
    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());

    final draft = actions.added.single;
    expect(draft.accountId, 'gcash');
    expect(draft.toAccountId, 'cash');
  });

  testWidgets('a transfer needs two accounts', (tester) async {
    await openSheet(tester, accounts: const [cashAccount]);
    await tapVisible(tester, find.text('Transfer'));
    expect(
      find.text('Add a second account to make transfers.'),
      findsOneWidget,
    );

    await tester.enterText(amountField(), '50');
    await tapVisible(tester, save());
    expect(
      find.textContaining('A transfer needs two accounts'),
      findsOneWidget,
    );
    expect(actions.added, isEmpty);
  });

  testWidgets('editing a transfer keeps From and To', (tester) async {
    final transfer = Transaction(
      id: 'tr-1',
      userId: 'u',
      accountId: 'gcash',
      toAccountId: 'cash',
      kind: TransactionKind.transfer,
      amountCents: 20000,
      occurredOn: DateTime(2026, 10, 2),
    );
    await openSheet(tester, existing: transfer);
    expect(find.text('Edit transfer'), findsOneWidget);

    await tapVisible(tester, save());
    final (id, draft) = actions.updated.single;
    expect(id, 'tr-1');
    expect(draft.accountId, 'gcash');
    expect(draft.toAccountId, 'cash');
  });

  testWidgets('"+ New" adds a category without leaving the form', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.byTooltip('New category'));
    expect(find.text('New expense category'), findsOneWidget);
  });

  testWidgets('"+ New" on the Income tab makes an income category', (
    tester,
  ) async {
    await openSheet(tester);
    await tapVisible(tester, find.text('Income'));
    await tapVisible(tester, find.byTooltip('New category'));
    expect(find.text('New income category'), findsOneWidget);
  });

  testWidgets('an expense can come from a sub-account (pocket)', (
    tester,
  ) async {
    const gotyme = Account(
      id: 'g',
      userId: 'u',
      name: 'GoTyme',
      type: AccountType.bank,
    );
    const travel = Account(
      id: 't',
      userId: 'u',
      name: 'Travel',
      type: AccountType.bank,
      parentId: 'g',
    );
    // Travel was made after Cash, but is listed right after GoTyme.
    await openSheet(tester, accounts: [gotyme, cashAccount, travel]);

    final labels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data)
        .where((l) => ['GoTyme', 'GoTyme › Travel', 'Cash'].contains(l));
    expect(labels, ['GoTyme', 'GoTyme › Travel', 'Cash']);

    await tester.enterText(amountField(), '2500');
    await tapVisible(tester, find.text('GoTyme › Travel'));
    await tapVisible(tester, save());
    expect(actions.added.single.accountId, 't');
  });
}

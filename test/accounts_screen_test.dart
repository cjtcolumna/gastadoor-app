import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chip_helpers.dart';

import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/presentation/accounts_screen.dart';

/// Keeps accounts in memory instead of Supabase.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this.start);

  final List<Account> start;
  final added = <(String, AccountType, int, String?)>[];
  final saved = <Account>[];

  @override
  Future<List<Account>> build() async => start;

  @override
  Future<void> add({
    required String name,
    required AccountType type,
    required int openingBalanceCents,
    String? parentId,
  }) async {
    added.add((name, type, openingBalanceCents, parentId));
  }

  @override
  Future<void> save(Account account) async => saved.add(account);

  final archivedIds = <String>[];
  final restoredIds = <String>[];

  @override
  Future<void> archive(String id) async => archivedIds.add(id);

  @override
  Future<void> restore(Account account) async => restoredIds.add(account.id);
}

const oldWallet = Account(
  id: '9',
  userId: 'u',
  name: 'Old Wallet',
  type: AccountType.eWallet,
  archived: true,
);

const cash = Account(
  id: '1',
  userId: 'u',
  name: 'Cash',
  type: AccountType.cash,
  openingBalanceCents: 50000,
);
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
const emergency = Account(
  id: 'e',
  userId: 'u',
  name: 'Emergency Fund',
  type: AccountType.bank,
  parentId: 'g',
);
const gotymeBalances = {'g': 5000000, 't': 700000, 'e': 200000};

const card = Account(
  id: '2',
  userId: 'u',
  name: 'BPI Card',
  type: AccountType.creditCard,
  openingBalanceCents: -12050,
);

void main() {
  late FakeAccountsNotifier fake;

  Future<void> pumpScreen(
    WidgetTester tester,
    List<Account> start, {
    Map<String, int> balances = const {},
    List<Account> archived = const [],
  }) async {
    fake = FakeAccountsNotifier(start);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => fake),
          accountBalancesProvider.overrideWith((ref) async => balances),
          archivedAccountsProvider.overrideWith((ref) async => archived),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder saveButton(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('lists accounts and the total', (tester) async {
    await pumpScreen(tester, [cash, card]);

    expect(find.text('Cash'), findsWidgets);
    expect(find.text('BPI Card'), findsOneWidget);
    expect(find.text('Credit card'), findsOneWidget);
    // 500.00 + (-120.50) = 379.50
    expect(find.text('₱379.50'), findsOneWidget);
  });

  testWidgets('shows current balances from the database when available', (
    tester,
  ) async {
    // Cash started at 500.00 but expenses brought it down to 320.00.
    await pumpScreen(tester, [cash, card], balances: {'1': 32000});

    expect(find.text('₱320.00'), findsOneWidget);
    // 320.00 + (-120.50) = 199.50
    expect(find.text('₱199.50'), findsOneWidget);
  });

  testWidgets('shows a friendly message when there are no accounts', (
    tester,
  ) async {
    await pumpScreen(tester, []);
    expect(find.textContaining('No accounts yet'), findsOneWidget);
  });

  testWidgets('adds an account with the amount in cents', (tester) async {
    await pumpScreen(tester, [cash]);
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();

    // Saving with no name shows an error and adds nothing.
    await tester.tap(saveButton('Add account'));
    await tester.pump();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(fake.added, isEmpty);

    await tester.enterText(field('Name'), 'GCash');
    await tester.tap(find.text('E-wallet'));
    await tester.enterText(field('Starting balance'), '1,500.50');
    await tester.tap(saveButton('Add account'));
    await tester.pumpAndSettle();

    expect(fake.added, [('GCash', AccountType.eWallet, 150050, null)]);
    expect(find.text('New account'), findsNothing); // sheet closed
  });

  testWidgets('edits an existing account', (tester) async {
    await pumpScreen(tester, [card]);
    await tester.tap(find.text('BPI Card'));
    await tester.pumpAndSettle();

    expect(find.text('Edit account'), findsOneWidget);
    expect(find.text('-120.50'), findsOneWidget); // prefilled from cents

    await tester.enterText(field('Starting balance'), '-200');
    await tester.tap(saveButton('Save'));
    await tester.pumpAndSettle();

    expect(fake.saved.single.openingBalanceCents, -20000);
    expect(fake.saved.single.id, '2');
  });

  testWidgets('archiving asks first and warns about money owed', (
    tester,
  ) async {
    await pumpScreen(tester, [cash, card]);
    await tester.tap(find.text('BPI Card'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Archive account'));
    await tester.tap(find.text('Archive account'));
    await tester.pumpAndSettle();
    expect(find.text('Archive BPI Card?'), findsOneWidget);
    expect(find.textContaining('BPI Card still owes ₱120.50'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.archivedIds, isEmpty);

    await tester.tap(find.text('Archive account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Archive'));
    await tester.pumpAndSettle();
    expect(fake.archivedIds, ['2']);
  });

  testWidgets('archived accounts can be restored', (tester) async {
    await pumpScreen(tester, [cash], archived: [oldWallet]);

    expect(find.text('Archived (1)'), findsOneWidget);
    expect(find.text('Old Wallet'), findsNothing); // closed at first

    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(fake.restoredIds, ['9']);
  });

  testWidgets('archived section shows even when no accounts are active', (
    tester,
  ) async {
    await pumpScreen(tester, [], archived: [oldWallet]);
    expect(find.textContaining('No accounts yet'), findsOneWidget);
    expect(find.text('Archived (1)'), findsOneWidget);
  });

  testWidgets('no archived section when nothing is archived', (tester) async {
    await pumpScreen(tester, [cash]);
    expect(find.textContaining('Archived ('), findsNothing);
  });

  testWidgets('archived section uses a rounded arrow', (tester) async {
    await pumpScreen(tester, [cash], archived: [oldWallet]);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
  });

  testWidgets('account type chips keep their icon when selected', (
    tester,
  ) async {
    await pumpScreen(tester, [cash]);
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-wallet'));
    await tester.pumpAndSettle();

    expect(checkmarksShown(tester, find.text('E-wallet')), isFalse);
    expect(find.byIcon(Icons.phone_iphone_rounded), findsOneWidget);
  });

  group('sub-accounts', () {
    testWidgets('a main account shows its total, then each pocket', (
      tester,
    ) async {
      await pumpScreen(tester, [
        gotyme,
        travel,
        emergency,
      ], balances: gotymeBalances);

      expect(find.text('Bank · 2 sub-accounts'), findsOneWidget);
      // ₱50,000 + ₱7,000 + ₱2,000. Also the "Total balance" at the top.
      expect(find.text('₱59,000.00'), findsNWidgets(2));
      expect(find.text('Main balance'), findsOneWidget);
      expect(find.text('₱50,000.00'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('₱7,000.00'), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('₱2,000.00'), findsOneWidget);
    });

    testWidgets('"Add a sub-account" makes a pocket inside the account', (
      tester,
    ) async {
      await pumpScreen(tester, [gotyme, cash]);
      await tester.tap(find.text('GoTyme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a sub-account'));
      await tester.pumpAndSettle();

      expect(find.text('New sub-account'), findsOneWidget);
      // Same type as GoTyme, so no type chips.
      expect(find.text('Bank, same as GoTyme'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'E-wallet'), findsNothing);

      await tester.enterText(field('Name'), 'Travel');
      await tester.enterText(field('Starting balance'), '7000');
      await tester.tap(saveButton('Add sub-account'));
      await tester.pumpAndSettle();

      expect(fake.added, [('Travel', AccountType.bank, 700000, 'g')]);
    });

    testWidgets('"Inside account" turns a new account into a pocket', (
      tester,
    ) async {
      await pumpScreen(tester, [gotyme, cash]);
      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('None (main account)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoTyme').last);
      await tester.pumpAndSettle();

      await tester.enterText(field('Name'), 'Emergency Fund');
      await tester.tap(saveButton('Add sub-account'));
      await tester.pumpAndSettle();
      expect(fake.added, [('Emergency Fund', AccountType.bank, 0, 'g')]);
    });

    testWidgets('a pocket has no "Add a sub-account" (one level only)', (
      tester,
    ) async {
      await pumpScreen(tester, [gotyme, travel]);
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit sub-account'), findsOneWidget);
      expect(find.text('Add a sub-account'), findsNothing);
    });

    testWidgets('an account with pockets cannot be moved into another', (
      tester,
    ) async {
      await pumpScreen(tester, [gotyme, travel, cash]);
      await tester.tap(find.text('GoTyme'));
      await tester.pumpAndSettle();

      expect(find.text('Inside account (optional)'), findsNothing);
    });

    testWidgets('archiving a main account warns about its pockets too', (
      tester,
    ) async {
      await pumpScreen(tester, [
        gotyme,
        travel,
        emergency,
      ], balances: gotymeBalances);
      await tester.tap(find.text('GoTyme'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Archive account'));
      await tester.tap(find.text('Archive account'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('GoTyme still has ₱59,000.00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Its 2 sub-accounts will be archived too'),
        findsOneWidget,
      );
    });

    testWidgets('pockets fit the smallest iPhone with double-size text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpScreen(tester, [
        gotyme,
        travel,
        emergency,
      ], balances: gotymeBalances);
      // Any overflow would be reported as an exception.
      expect(tester.takeException(), isNull);
      expect(find.text('Emergency Fund'), findsOneWidget);
    });
  });
}

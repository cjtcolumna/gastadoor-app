import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/presentation/accounts_screen.dart';

/// Keeps accounts in memory instead of Supabase.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this.start);

  final List<Account> start;
  final added = <(String, AccountType, int)>[];
  final saved = <Account>[];

  @override
  Future<List<Account>> build() async => start;

  @override
  Future<void> add({
    required String name,
    required AccountType type,
    required int openingBalanceCents,
  }) async {
    added.add((name, type, openingBalanceCents));
  }

  @override
  Future<void> save(Account account) async => saved.add(account);

  final archivedIds = <String>[];
  final restoredIds = <String>[];

  @override
  Future<void> archive(String id) async => archivedIds.add(id);

  @override
  Future<void> restore(String id) async => restoredIds.add(id);
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
        child: const MaterialApp(home: AccountsScreen()),
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

    expect(fake.added, [('GCash', AccountType.eWallet, 150050)]);
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
}

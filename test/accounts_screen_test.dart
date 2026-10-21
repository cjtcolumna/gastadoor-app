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

  @override
  Future<void> archive(String id) async {}
}

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

  Future<void> pumpScreen(WidgetTester tester, List<Account> start) async {
    fake = FakeAccountsNotifier(start);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountsProvider.overrideWith(() => fake)],
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

  testWidgets('shows a friendly message when there are no accounts', (
    tester,
  ) async {
    await pumpScreen(tester, []);
    expect(find.textContaining('No accounts yet'), findsOneWidget);
  });

  testWidgets('adds an account with the amount in cents', (tester) async {
    await pumpScreen(tester, [cash]);
    await tester.tap(find.byType(FloatingActionButton));
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
}

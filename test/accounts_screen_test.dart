import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'chip_helpers.dart';

import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/accounts/presentation/account_detail_screen.dart';
import 'package:gastadoor/features/accounts/presentation/accounts_screen.dart';
import 'package:gastadoor/features/accounts/presentation/pocket_bubble.dart';
import 'package:gastadoor/features/transactions/data/transaction_actions.dart';
import 'package:gastadoor/features/transactions/domain/transaction.dart';
import 'package:gastadoor/features/transactions/domain/transaction_draft.dart';

/// What the screens asked to add: name, type, starting cents, parent id,
/// icon, goal cents.
typedef Added = (String, AccountType, int, String?, String?, int?);

/// Keeps accounts in memory instead of Supabase.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this.start);

  final List<Account> start;
  final added = <Added>[];
  final saved = <Account>[];

  @override
  Future<List<Account>> build() async => start;

  @override
  Future<void> add({
    required String name,
    required AccountType type,
    required int openingBalanceCents,
    String? parentId,
    String? icon,
    int? goalCents,
  }) async {
    added.add((name, type, openingBalanceCents, parentId, icon, goalCents));
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

/// Records transfers made with "Add money" / "Take out".
class FakeActions implements TransactionActions {
  final added = <TransactionDraft>[];

  @override
  Future<void> add(TransactionDraft draft) async => added.add(draft);

  @override
  Future<void> update(String id, TransactionDraft draft) async {}

  @override
  Future<void> delete(String id) async {}
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
  icon: 'flight',
  goalCents: 2000000, // ₱20,000
);
const emergency = Account(
  id: 'e',
  userId: 'u',
  name: 'Emergency Fund',
  type: AccountType.bank,
  parentId: 'g',
  icon: 'emergency',
);
const gotymeBalances = {'g': 5000000, 't': 700000, 'e': 200000};

void main() {
  late FakeAccountsNotifier fake;
  late FakeActions actions;

  /// Shows the Accounts tab (or [location], e.g. '/accounts/g') inside a
  /// small router, so tapping an account can open its page.
  Future<void> pumpScreen(
    WidgetTester tester,
    List<Account> start, {
    Map<String, int> balances = const {},
    List<Account> archived = const [],
    String location = '/accounts',
  }) async {
    fake = FakeAccountsNotifier(start);
    actions = FakeActions();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  AccountDetailScreen(accountId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => fake),
          accountBalancesProvider.overrideWith((ref) async => balances),
          archivedAccountsProvider.overrideWith((ref) async => archived),
          transactionActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  Finder saveButton(String label) => find.widgetWithText(FilledButton, label);

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Accounts tab', () {
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

      expect(fake.added, [
        ('GCash', AccountType.eWallet, 150050, null, null, null),
      ]);
      expect(find.text('New account'), findsNothing); // sheet closed
    });

    testWidgets('only main accounts are listed, with their totals', (
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
      // Sub-accounts live on the account's own page, not here.
      expect(find.text('Travel'), findsNothing);
      expect(find.text('Emergency Fund'), findsNothing);
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
  });

  group('account page', () {
    testWidgets('tapping an account opens its page', (tester) async {
      await pumpScreen(tester, [
        gotyme,
        travel,
        emergency,
        cash,
      ], balances: gotymeBalances);
      await tester.tap(find.text('GoTyme'));
      await tester.pumpAndSettle();

      expect(find.text('Main balance'), findsOneWidget);
      expect(find.text('₱50,000.00'), findsOneWidget);
      expect(find.text('Total with sub-accounts'), findsOneWidget);
      expect(find.text('₱59,000.00'), findsOneWidget);
    });

    testWidgets('sub-accounts show as bubbles with their goal', (tester) async {
      await pumpScreen(
        tester,
        [gotyme, travel, emergency],
        balances: gotymeBalances,
        location: '/accounts/g',
      );

      expect(find.byType(PocketBubble), findsNWidgets(2));
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('35% of ₱20,000'), findsOneWidget);
      expect(find.byIcon(Icons.flight_rounded), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('No goal'), findsOneWidget);
      expect(find.byType(AddPocketBubble), findsOneWidget);
    });

    testWidgets('bubbles sit two per row', (tester) async {
      await pumpScreen(
        tester,
        [gotyme, travel, emergency],
        balances: gotymeBalances,
        location: '/accounts/g',
      );

      final travelTop = tester.getTopLeft(find.byType(PocketBubble).first);
      final emergencyTop = tester.getTopLeft(find.byType(PocketBubble).last);
      final addTop = tester.getTopLeft(find.byType(AddPocketBubble));
      // Travel and Emergency Fund side by side; "Add" on the next row.
      expect(emergencyTop.dy, travelTop.dy);
      expect(emergencyTop.dx, greaterThan(travelTop.dx));
      expect(addTop.dy, greaterThan(travelTop.dy));
      expect(addTop.dx, travelTop.dx);
    });

    testWidgets('a goal that is reached gets a check mark', (tester) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: {'g': 0, 't': 2500000}, // ₱25,000 of ₱20,000
        location: '/accounts/g',
      );
      expect(find.text('Goal reached'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('the ring fills to the saved share of the goal', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<GoalRingPainter>()
          .single;
      expect(painter.progress, closeTo(0.35, 1e-9));
      expect(painter.hasGoal, isTrue);
    });

    testWidgets('adding a sub-account saves its icon and goal', (tester) async {
      await pumpScreen(tester, [gotyme], location: '/accounts/g');
      expect(find.textContaining('Set money aside'), findsOneWidget);

      await tester.tap(find.byType(AddPocketBubble));
      await tester.pumpAndSettle();
      expect(find.text('New sub-account'), findsOneWidget);
      expect(find.text('Inside GoTyme'), findsOneWidget);

      await tester.enterText(field('Name'), 'Travel');
      await tapVisible(tester, find.bySemanticsLabel('flight icon'));
      await tester.enterText(field('Goal (optional)'), '20,000');
      await tester.enterText(field('Starting balance'), '500');
      await tapVisible(tester, saveButton('Add sub-account'));

      expect(fake.added, [
        ('Travel', AccountType.bank, 50000, 'g', 'flight', 2000000),
      ]);
    });

    testWidgets('an empty goal means no goal', (tester) async {
      await pumpScreen(tester, [gotyme], location: '/accounts/g');
      await tester.tap(find.byType(AddPocketBubble));
      await tester.pumpAndSettle();

      await tester.enterText(field('Name'), 'Buffer');
      await tapVisible(tester, saveButton('Add sub-account'));

      // Default icon (piggy bank), no goal.
      expect(fake.added, [
        ('Buffer', AccountType.bank, 0, 'g', 'savings', null),
      ]);
    });

    testWidgets('"Add money" opens a transfer from the main account', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      await tester.tap(find.byType(PocketBubble));
      await tester.pumpAndSettle();
      expect(find.text('Add money'), findsOneWidget);
      expect(find.text('Take out'), findsOneWidget);

      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();
      expect(find.text('New transfer'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '1000');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));

      final draft = actions.added.single;
      expect(draft.kind, TransactionKind.transfer);
      expect(draft.accountId, 'g'); // from GoTyme
      expect(draft.toAccountId, 't'); // to Travel
      expect(draft.amountCents, 100000);
    });

    testWidgets('"Take out" moves money back to the main account', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      await tester.tap(find.byType(PocketBubble));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take out'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '250');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));

      final draft = actions.added.single;
      expect(draft.accountId, 't');
      expect(draft.toAccountId, 'g');
    });

    testWidgets('editing a sub-account can remove its goal', (tester) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      await tester.tap(find.byType(PocketBubble));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit sub-account'));
      await tester.pumpAndSettle();

      expect(find.text('20000.00'), findsOneWidget); // goal prefilled
      await tester.enterText(field('Goal (optional)'), '');
      await tapVisible(tester, saveButton('Save'));

      final saved = fake.saved.single;
      expect(saved.id, 't');
      expect(saved.goalCents, isNull);
      expect(saved.icon, 'flight');
      expect(saved.parentId, 'g');
    });

    testWidgets('edits the main account from its page', (tester) async {
      await pumpScreen(tester, [card], location: '/accounts/2');
      await tester.tap(find.byTooltip('Edit account'));
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
      await pumpScreen(tester, [cash, card], location: '/accounts/2');
      await tester.tap(find.byTooltip('Edit account'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Archive account'));
      expect(find.text('Archive BPI Card?'), findsOneWidget);
      expect(
        find.textContaining('BPI Card still owes ₱120.50'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.archivedIds, isEmpty);

      await tester.tap(find.text('Archive account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(fake.archivedIds, ['2']);
    });

    testWidgets('archiving a main account warns about its sub-accounts', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        [gotyme, travel, emergency],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      await tester.tap(find.byTooltip('Edit account'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Archive account'));

      expect(
        find.textContaining('GoTyme still has ₱59,000.00'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Its 2 sub-accounts will be archived too'),
        findsOneWidget,
      );
    });

    testWidgets('a missing account shows a way back', (tester) async {
      await pumpScreen(tester, [cash], location: '/accounts/nope');
      expect(find.textContaining("isn't here anymore"), findsOneWidget);
      await tester.tap(find.text('Back to accounts'));
      await tester.pumpAndSettle();
      expect(find.text('Total balance'), findsOneWidget);
    });

    testWidgets('fits the smallest iPhone with double-size text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpScreen(
        tester,
        [gotyme, travel, emergency],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      // Any overflow would be reported as an exception.
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(AddPocketBubble), 200);
      expect(tester.takeException(), isNull);
    });
  });

  group('bank icons', () {
    bool showsIcon(WidgetTester tester, String id) => tester
        .widgetList<Image>(find.byType(Image))
        .any(
          (img) =>
              img.image is AssetImage &&
              (img.image as AssetImage).assetName == 'assets/banks/$id.png',
        );

    testWidgets('a known bank shows its own icon, others the usual one', (
      tester,
    ) async {
      await pumpScreen(tester, [gotyme, cash]);
      expect(showsIcon(tester, 'gotyme'), isTrue);
      // Cash isn't a bank: the round icon, no picture.
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    });

    testWidgets('typing a bank name shows a preview and picks the type', (
      tester,
    ) async {
      await pumpScreen(tester, [cash]);
      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Name'), 'GCash Wallet');
      await tester.pumpAndSettle();
      expect(find.textContaining('Looks like GCash'), findsOneWidget);
      expect(showsIcon(tester, 'gcash'), isTrue);

      await tester.tap(saveButton('Add account'));
      await tester.pumpAndSettle();
      expect(fake.added.single.$2, AccountType.eWallet);
    });

    testWidgets('a type picked by hand is not changed by the name', (
      tester,
    ) async {
      await pumpScreen(tester, [cash]);
      await tester.tap(find.byTooltip('Add account'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Credit card'));
      await tester.enterText(field('Name'), 'BPI Card');
      await tester.pumpAndSettle();
      await tester.tap(saveButton('Add account'));
      await tester.pumpAndSettle();
      expect(fake.added.single.$2, AccountType.creditCard);
    });

    testWidgets("a bank's page has a banner in its color", (tester) async {
      await pumpScreen(
        tester,
        [gotyme, travel],
        balances: gotymeBalances,
        location: '/accounts/g',
      );
      final banner = tester.widget<Card>(find.byType(Card).first);
      expect(banner.color, const Color(0xFF05E6FA));
      expect(find.text('GoTyme Bank · Bank'), findsOneWidget);
    });

    testWidgets('sub-accounts keep their own icons', (tester) async {
      const bpiPocket = Account(
        id: 'p',
        userId: 'u',
        name: 'BPI',
        type: AccountType.bank,
        parentId: 'g',
      );
      await pumpScreen(tester, [gotyme, bpiPocket], location: '/accounts/g');
      expect(showsIcon(tester, 'bpi'), isFalse);
    });
  });
}

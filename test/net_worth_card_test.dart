import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastadoor/core/theme/app_theme.dart';
import 'package:gastadoor/features/accounts/data/accounts_provider.dart';
import 'package:gastadoor/features/accounts/domain/account.dart';
import 'package:gastadoor/features/home/presentation/net_worth_card.dart';
import 'package:gastadoor/features/loans/data/loans_provider.dart';
import 'package:gastadoor/features/loans/domain/loan.dart';
import 'package:gastadoor/features/loans/domain/loan_summary.dart';
import 'package:go_router/go_router.dart';

const gotyme = Account(
  id: 'gotyme',
  userId: 'u',
  name: 'GoTyme',
  type: AccountType.bank,
);
const cash = Account(
  id: 'cash',
  userId: 'u',
  name: 'Cash',
  type: AccountType.cash,
);

class _Accounts extends AccountsNotifier {
  _Accounts(this.start);

  final List<Account> start;

  @override
  Future<List<Account>> build() async => start;
}

class _Loans extends LoansNotifier {
  _Loans(this.start);

  final List<LoanWithPayments> start;

  @override
  Future<List<LoanWithPayments>> build() async => start;
}

LoanWithPayments owed(
  String id,
  String person,
  int cents, {
  int paid = 0,
  DateTime? dueOn,
}) => LoanWithPayments(
  Loan(
    id: id,
    userId: 'u',
    person: person,
    amountCents: cents,
    lentOn: DateTime(2026, 10, 1),
    dueOn: dueOn,
  ),
  [
    if (paid > 0)
      LoanPayment(
        id: 'p$id',
        userId: 'u',
        loanId: id,
        amountCents: paid,
        paidOn: DateTime(2026, 10, 10),
      ),
  ],
);

/// The green card at the top of Home: accounts plus money owed to you.
void main() {
  // GoTyme ₱5,000.00 + Cash ₱100.00 = ₱5,100.00 in accounts.
  const balances = {'gotyme': 500000, 'cash': 10000};

  Future<void> pumpCard(
    WidgetTester tester, {
    List<LoanWithPayments> loans = const [],
    Map<String, int> accountBalances = balances,
    List<Account> accounts = const [gotyme, cash],
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: NetWorthCard()),
          ),
        ),
        GoRoute(path: '/loans', builder: (_, _) => const Text('Loans page')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => _Accounts(accounts)),
          accountBalancesProvider.overrideWith((ref) async => accountBalances),
          loansProvider.overrideWith(() => _Loans(loans)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nobody owes you', () {
    testWidgets('looks like before: the total and how many accounts', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.text('Net worth'), findsOneWidget);
      expect(find.text('₱5,100.00'), findsOneWidget);
      expect(find.text('Across 2 accounts'), findsOneWidget);
      expect(find.text('Owed to you'), findsNothing);
      expect(find.text('In 2 accounts'), findsNothing);
    });

    testWidgets('loans that are all paid back count as nothing owed', (
      tester,
    ) async {
      await pumpCard(tester, loans: [owed('a', 'Mark', 100000, paid: 100000)]);
      expect(find.text('₱5,100.00'), findsOneWidget);
      expect(find.text('Across 2 accounts'), findsOneWidget);
      expect(find.text('Owed to you'), findsNothing);
    });
  });

  group('someone owes you', () {
    testWidgets('net worth adds what you are owed, with both parts shown', (
      tester,
    ) async {
      await pumpCard(
        tester,
        loans: [
          owed('a', 'Mark', 100000, paid: 25000), // ₱750.00 still owed
          owed('b', 'Ana', 50000), // ₱500.00
        ],
      );
      // ₱5,100.00 in accounts + ₱1,250.00 owed.
      expect(find.text('₱6,350.00'), findsOneWidget);
      expect(find.text('In 2 accounts'), findsOneWidget);
      expect(find.text('₱5,100.00'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('₱1,250.00'), findsOneWidget);
      // The chips replace the "Across 2 accounts" line.
      expect(find.text('Across 2 accounts'), findsNothing);
    });

    testWidgets('lending money does not make net worth drop', (tester) async {
      // Before: ₱6,000.00 in the accounts, nobody owes you.
      await pumpCard(
        tester,
        accountBalances: {'gotyme': 590000, 'cash': 10000},
      );
      expect(find.text('₱6,000.00'), findsOneWidget);

      // After lending ₱1,000.00 from GoTyme: the account is lower, but the
      // ₱1,000.00 owed to you is counted, so the total is the same.
      await tester.pumpWidget(const SizedBox());
      await pumpCard(
        tester,
        accountBalances: {'gotyme': 490000, 'cash': 10000},
        loans: [owed('a', 'Mark', 100000)],
      );
      expect(find.text('₱6,000.00'), findsOneWidget);
      expect(find.text('₱5,000.00'), findsOneWidget); // now in accounts
      expect(find.text('₱1,000.00'), findsOneWidget); // owed
    });

    testWidgets('a repayment moves money from "owed" to "in accounts"', (
      tester,
    ) async {
      // ₱400.00 of the ₱1,000.00 came back into Cash.
      await pumpCard(
        tester,
        accountBalances: {'gotyme': 490000, 'cash': 50000},
        loans: [owed('a', 'Mark', 100000, paid: 40000)],
      );
      expect(find.text('₱6,000.00'), findsOneWidget); // unchanged
      expect(find.text('₱5,400.00'), findsOneWidget);
      expect(find.text('₱600.00'), findsOneWidget);
    });

    testWidgets('a single account says "account", not "accounts"', (
      tester,
    ) async {
      await pumpCard(
        tester,
        accounts: const [gotyme],
        accountBalances: {'gotyme': 100000},
        loans: [owed('a', 'Mark', 50000)],
      );
      expect(find.text('In 1 account'), findsOneWidget);
      expect(find.text('₱1,500.00'), findsOneWidget); // 1,000 + 500 owed
    });

    testWidgets('with nobody owing you, one account says "Across 1 account"', (
      tester,
    ) async {
      await pumpCard(
        tester,
        accounts: const [gotyme],
        accountBalances: {'gotyme': 100000},
      );
      expect(find.text('Across 1 account'), findsOneWidget);
    });

    testWidgets('tapping "Owed to you" opens the Loans list', (tester) async {
      await pumpCard(tester, loans: [owed('a', 'Mark', 100000)]);
      await tester.tap(find.text('Owed to you'));
      await tester.pumpAndSettle();
      expect(find.text('Loans page'), findsOneWidget);
    });

    testWidgets('the "In accounts" chip is not a button', (tester) async {
      await pumpCard(tester, loans: [owed('a', 'Mark', 100000)]);
      await tester.tap(find.text('In 2 accounts'));
      await tester.pumpAndSettle();
      expect(find.text('Loans page'), findsNothing);
      expect(find.text('Net worth'), findsOneWidget);
    });

    testWidgets('fits on a narrow phone, even with huge amounts', (
      tester,
    ) async {
      await pumpCard(
        tester,
        width: 320,
        accountBalances: {'gotyme': 987654321, 'cash': 123456789},
        loans: [
          owed(
            'a',
            'Mark',
            555555555,
            dueOn: DateTime(2020, 1, 1), // overdue, so the note shows too
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });
  });

  group('overdue loans', () {
    testWidgets('the chip says how many are overdue', (tester) async {
      final past = DateTime(2020, 1, 1);
      await pumpCard(
        tester,
        loans: [
          owed('a', 'Mark', 100000, dueOn: past),
          owed('b', 'Ana', 50000, dueOn: past),
          owed('c', 'Leo', 20000, dueOn: DateTime(2999, 1, 1)), // not due yet
        ],
      );
      expect(find.text('2 overdue'), findsOneWidget);
    });

    testWidgets('no note when nothing is overdue', (tester) async {
      await pumpCard(
        tester,
        loans: [
          owed('a', 'Mark', 100000, dueOn: DateTime(2999, 1, 1)),
          owed('b', 'Ana', 50000),
        ],
      );
      expect(find.textContaining('overdue'), findsNothing);
    });

    testWidgets('a paid-back loan is not counted as overdue', (tester) async {
      await pumpCard(
        tester,
        loans: [
          owed('a', 'Mark', 100000, paid: 100000, dueOn: DateTime(2020, 1, 1)),
          owed('b', 'Ana', 50000),
        ],
      );
      expect(find.textContaining('overdue'), findsNothing);
    });
  });
}
